import {createPublicClient, http, encodeFunctionData, encodeAbiParameters, keccak256, toHex, parseTransaction, type Hex, type Address} from "npm:viem@2.38.0";
import {privateKeyToAccount} from "npm:viem@2.38.0/accounts";
import {decode} from "npm:cbor-x@1.6.0/decode-no-eval";

type Context={env:Record<string,string>,dataDir:string};
type Entry={raw:Hex,hash:Hex,complete:boolean,success?:boolean};
type Mail={at:number,message:Record<string,unknown>};
type State={transactions:Record<string,Entry>,boxes:Record<string,Mail[]>};
const abi=JSON.parse(await Deno.readTextFile(new URL('./abi.json',import.meta.url)));
const deployment=JSON.parse(await Deno.readTextFile(new URL('./network.json',import.meta.url)));
const response=(body:unknown,status=200)=>Response.json(body,{status});
function need(ok:unknown,message:string):asserts ok {if(!ok)throw new Error(message);}
function binary(value:unknown):Uint8Array {need(typeof value==='string' && value.length<64000,'invalid base64');return Uint8Array.from(atob(value),c=>c.charCodeAt(0));}
function hex(value:unknown,size?:number):Hex {need(typeof value==='string' && /^0x(?:[0-9a-fA-F]{2})*$/.test(value) && (size===undefined || value.length===2+size*2),'invalid hex');return value as Hex;}
function integer(value:unknown):bigint {need(typeof value==='string'||typeof value==='number','invalid number');const n=BigInt(value);need(n>=0n,'negative number');return n;}
function signature(der:Uint8Array):[bigint,bigint] {
    need(der.length>=8 && der[0]===0x30 && der[1]===der.length-2,'invalid assertion signature');
    let offset=2;
    const scalar=()=>{need(der[offset++]===2,'invalid signature integer');const size=der[offset++];need(size>0&&size<=33&&offset+size<=der.length,'signature extent');const b=der.slice(offset,offset+size);offset+=size;need(b[0]<128 && (b[0]!==0||size===1||b[1]>=128),'noncanonical signature');return BigInt(toHex(b));};
    const r=scalar(),s=scalar();need(offset===der.length,'signature trailing bytes');return [r,s];
}
export class Relay {
    private state:State={transactions:{},boxes:{}};
    private writeQueue:Promise<unknown>=Promise.resolve();
    private txQueue:Promise<unknown>=Promise.resolve();
    private account;
    private client;
    private directory:string;
    private initialized:Promise<void>;
    constructor(context:Context) {
        this.account=privateKeyToAccount(hex(context.env.PRIVATE_KEY,32));
        this.client=createPublicClient({transport:http(context.env.RPC_URL || 'https://sepolia.base.org',{timeout:30000,retryCount:1})});
        this.directory=context.dataDir;
        this.initialized=this.load();
    }
    private async load() {
        need([31337,84532].includes(deployment.chainId),'test networks only');
        need(await this.client.getChainId()===deployment.chainId,'wrong chain');
        need(this.account.address.toLowerCase()===deployment.admin.toLowerCase(),'wrong sponsor');
        await Deno.mkdir(this.directory,{recursive:true});
        try {this.state=JSON.parse(await Deno.readTextFile(this.directory+'/state.json'));}
        catch(e) {if(!(e instanceof Deno.errors.NotFound))throw e;}
    }
    private save() {
        const content=JSON.stringify(this.state);
        const operation=this.writeQueue.then(async()=>{
            const path=this.directory+'/state.tmp';
            const f=await Deno.open(path,{write:true,create:true,truncate:true,mode:0o600});
            try {const bytes=new TextEncoder().encode(content);let n=0;while(n<bytes.length)n+=await f.write(bytes.subarray(n));await f.sync();}finally{f.close();}
            await Deno.rename(path,this.directory+'/state.json');
        });
        this.writeQueue=operation.catch(()=>{});return operation;
    }
    private async settle(entry:Entry):Promise<Hex> {
        if(entry.complete){need(entry.success===true,"transaction reverted");return entry.hash;}
        let receipt;
        try {receipt=await this.client.getTransactionReceipt({hash:entry.hash});}catch { /* May not have been sent yet. */ }
        if(!receipt) {
            try {await this.client.sendRawTransaction({serializedTransaction:entry.raw});}catch(e) {
                const details=e as {shortMessage?:string,details?:string};
                const message=String(details.details||details.shortMessage||'submission failed');
                const transaction=parseTransaction(entry.raw);
                console.error('Transaction submission result',JSON.stringify({hash:entry.hash,gas:transaction.gas?.toString(),message:message.slice(0,400)}));
                // Repair only this explicit sequencer rejection, retaining destination,
                // calldata and nonce. A replacement cannot execute twice at one nonce.
                if(deployment.chainId===84532 && message.toLowerCase().includes('gas limit too high') && transaction.type==='legacy' && transaction.gas!>16000000n) {
                    const estimate=await this.client.estimateGas({account:this.account,to:transaction.to!,data:transaction.data});
                    need(estimate<=16000000n,'enrollment exceeds relay gas cap');
                    entry.raw=await this.account.signTransaction({type:'legacy',chainId:deployment.chainId,to:transaction.to!,data:transaction.data,nonce:transaction.nonce!,gas:estimate+estimate/10n>16000000n?16000000n:estimate+estimate/10n,gasPrice:transaction.gasPrice!});
                    entry.hash=keccak256(entry.raw);await this.save();
                    return await this.settle(entry);
                }
                // Already known/mined is resolved by the receipt below.
            }
            receipt=await this.client.waitForTransactionReceipt({hash:entry.hash,timeout:90000,pollingInterval:1000});
        }
        // Persist the terminal state even on revert, so it cannot block later requests.
        if(deployment.chainId===84532)await new Promise(resolve=>setTimeout(resolve,4000));
        entry.complete=true;entry.success=receipt.status==='success';await this.save();
        need(receipt.status==='success','transaction reverted');return entry.hash;
    }
    private transact(to:Address,data:Hex):Promise<Hex> {
        const operation=this.txQueue.then(async()=>{
            const id=keccak256((to.toLowerCase()+data.slice(2)) as Hex);
            if(this.state.transactions[id])return await this.settle(this.state.transactions[id]);
            for(const entry of Object.values(this.state.transactions))if(!entry.complete)await this.settle(entry);
            need(Object.keys(this.state.transactions).length<10000,'relay transaction journal full');
            const gas=await this.client.estimateGas({account:this.account,to,data});
            const nonce=await this.client.getTransactionCount({address:this.account.address,blockTag:'pending'});
            const gasPrice=await this.client.getGasPrice()*2n;
            need(deployment.chainId!==84532 || gas<=16000000n,'enrollment exceeds relay gas cap');
            const limit=deployment.chainId===84532 && gas+gas/10n>16000000n?16000000n:gas+gas/10n;
            const raw=await this.account.signTransaction({chainId:deployment.chainId,to,data,nonce,gas:limit,gasPrice,type:'legacy'});
            const entry={raw,hash:keccak256(raw),complete:false};this.state.transactions[id]=entry;
            // The exact signed transaction is durable BEFORE submission; retries reuse it.
            await this.save();return await this.settle(entry);
        });
        this.txQueue=operation.catch(()=>{});return operation;
    }
    async handle(request:Request) {
        await this.initialized;
        const path=new URL(request.url).pathname.replace(/\/$/,'');
        if(request.method==='GET' && ['/info','/_warmup'].includes(path))return response({owner:this.account.address,chainId:deployment.chainId,registry:deployment.DemoV1,protocolVersion:2});
        if(request.method==='GET' && path==='/status')return response({pending:Object.values(this.state.transactions).filter(e=>!e.complete).map(e=>({hash:e.hash,gas:parseTransaction(e.raw).gas?.toString()})),completed:Object.values(this.state.transactions).filter(e=>e.complete).length});
        if(request.method==='GET' && path.startsWith('/recv/')) {
            const name=path.slice(6);need(/^[a-zA-Z0-9_-]{1,80}$/.test(name),'invalid mailbox');
            const queue=(this.state.boxes[name]||[]).filter(x=>Date.now()-x.at<120000);
            const entry=queue.shift();if(queue.length)this.state.boxes[name]=queue;else delete this.state.boxes[name];
            if(entry)await this.save();return response({message:entry?.message||null});
        }
        need(request.method==='POST','unknown route');
        const reader=request.body?.getReader();need(reader,'missing request body');let raw='';let size=0;const decoder=new TextDecoder();
        while(true){const chunk=await reader.read();if(chunk.done)break;size+=chunk.value.length;if(size>65536){await reader.cancel();throw new Error('request too large');}raw+=decoder.decode(chunk.value,{stream:true});}raw+=decoder.decode();
        const body=JSON.parse(raw);
        if(path.startsWith('/send/')) {
            const name=path.slice(6);need(/^[a-zA-Z0-9_-]{1,80}$/.test(name),'invalid mailbox');
            need(size<=8192 && typeof body.from==='string' && /^[a-zA-Z0-9_-]{1,80}$/.test(body.from),'invalid message');
            need(['HELLO','PARCEL','PROOF','ERROR'].includes(body.type),'unsupported message type');
            for(const [key,items] of Object.entries(this.state.boxes)){const live=items.filter(x=>Date.now()-x.at<120000);if(live.length)this.state.boxes[key]=live;else delete this.state.boxes[key];}
            need(this.state.boxes[name]||Object.keys(this.state.boxes).length<500,'mailbox limit');
            const queue=this.state.boxes[name]||[];need(queue.length<32,'mailbox full');queue.push({at:Date.now(),message:body});this.state.boxes[name]=queue;await this.save();return response({queued:queue.length});
        }
        if(path==='/enroll') {
            need(hex(body.category,32).toLowerCase()===deployment.macCategory.toLowerCase(),'unknown category');
            const evidence=decode(binary(body.attestation));
            const data=encodeFunctionData({abi:abi.adapter,functionName:'enroll',args:[toHex(evidence.attStmt.x5c[0]),toHex(evidence.authData),hex(body.clientData,32)]});
            return response({tx:await this.transact(deployment.macAdapter,data)});
        }
        if(path==='/execute') {
            const r=body.request;need(r&&[0,2,3].includes(r.action),'unsupported action');
            need(hex(r.category,32).toLowerCase()===deployment.macCategory.toLowerCase(),'unknown category');
            need(r.owner?.toLowerCase()===this.account.address.toLowerCase()&&r.memberSigner?.toLowerCase()===this.account.address.toLowerCase(),'wrong owner');
            const value={action:r.action,category:hex(r.category,32),owner:this.account.address,memberSigner:this.account.address,sessionKeyHash:hex(r.sessionKeyHash,32),nonce:integer(r.nonce),validUntil:integer(r.validUntil),scope:hex(r.scope,32),keyX:integer(r.keyX),keyY:integer(r.keyY),envelopeDigest:hex(r.envelopeDigest,32)};
            const context=await this.client.readContract({address:deployment.DemoV1,abi:abi.demo,functionName:'contextHash',args:[value]}) as Hex;
            need(context.toLowerCase()===hex(body.context,32).toLowerCase(),'request context mismatch');
            const assertion=decode(binary(body.assertion));const [x,y]=signature(assertion.signature);
            const kid=binary(body.keyId);need(kid.length===32,'invalid key ID');
            const proof=encodeAbiParameters([{type:'bytes32'},{type:'bytes'},{type:'uint256'},{type:'uint256'}],[toHex(kid),toHex(assertion.authenticatorData),x,y]);
            const memberSignature=await this.account.signMessage({message:{raw:context}});
            const data=encodeFunctionData({abi:abi.demo,functionName:'execute',args:[value,proof,memberSignature,hex(body.groupSignature)]});
            return response({tx:await this.transact(deployment.DemoV1,data)});
        }
        return response({error:'unknown route'},404);
    }
}
let relay:Relay|undefined;
export default async function handler(request:Request,context:Context) {
    try {relay ??= new Relay(context);return await relay.handle(request);}
    catch(e) {console.error('Relay request failed:',e instanceof Error?e.name:'unknown');return response({error:e instanceof Error && e.name==='Error'?e.message:'relay transaction unavailable; retry'},503);}
}
if(import.meta.main) {
    const context={env:Deno.env.toObject(),dataDir:Deno.env.get('RELAY_DATA')||'./relay-data'};
    Deno.serve({hostname:'127.0.0.1',port:Number(Deno.env.get('PORT')||18577)},r=>handler(r,context));
}
