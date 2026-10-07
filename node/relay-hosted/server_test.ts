import {privateKeyToAccount} from "npm:viem@2.38.0/accounts";

Deno.test('legacy and NFT routes retain separate admission and mailboxes with one journal',async()=>{
    // Public Anvil fixture key, never a deployed sponsor credential.
    const key='0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
    const directory=await Deno.makeTempDir();
    const rpc=Deno.serve({hostname:'127.0.0.1',port:0,onListen:()=>{}},async request=>{
        const value=await request.json();
        if(value.method!=='eth_chainId')throw new Error('Unexpected RPC call: '+value.method);
        return Response.json({jsonrpc:'2.0',id:value.id,result:'0x7a69'});
    });
    const check=(condition:unknown,message:string)=>{if(!condition)throw new Error(message);};
    try {
        for(const name of ['server.ts','abi.json','badge-abi.json'])
            await Deno.copyFile(new URL(name,import.meta.url),directory+'/'+name);
        const fixture=JSON.parse(await Deno.readTextFile(new URL('network.json',import.meta.url)));
        fixture.chainId=31337;fixture.admin=privateKeyToAccount(key).address;
        delete fixture.ResearchBadges;delete fixture.PersonalBadgeAccountFactory;
        const nft={...fixture,DemoV1:'0x1111111111111111111111111111111111111111',macCategory:'0x'+'22'.repeat(32),ResearchBadges:'0x3333333333333333333333333333333333333333',PersonalBadgeAccountFactory:'0x4444444444444444444444444444444444444444'};
        await Deno.writeTextFile(directory+'/network.json',JSON.stringify(fixture));
        await Deno.writeTextFile(directory+'/network-nft.json',JSON.stringify(nft));
        const dataDir=directory+'/data';await Deno.mkdir(dataDir);
        await Deno.writeTextFile(dataDir+'/state.json',JSON.stringify({transactions:{retained:{raw:'0x',hash:'0x'+'55'.repeat(32),complete:true,success:true}},boxes:{}}));
        const {default:handler}=await import('file://'+directory+'/server.ts');
        const context={env:{PRIVATE_KEY:key,RPC_URL:'http://127.0.0.1:'+rpc.addr.port},dataDir};
        const call=async(path:string,body?:unknown)=>{
            const result=await handler(new Request('http://relay'+path,body===undefined?{}:{method:'POST',body:JSON.stringify(body)}),context);
            return {status:result.status,body:await result.json()};
        };
        check((await call('/info')).body.registry===fixture.DemoV1,'legacy network changed');
        check((await call('/nft/info')).body.registry===nft.DemoV1,'NFT network missing');
        check((await call('/status')).body.completed===1,'existing journal lost');
        check((await call('/nft/status')).body.completed===1,'sponsor journal not shared');
        await call('/send/same-name',{from:'old',type:'HELLO'});
        await call('/nft/send/same-name',{from:'new',type:'HELLO'});
        check((await call('/recv/same-name')).body.message.from==='old','legacy mailbox crossed networks');
        check((await call('/nft/recv/same-name')).body.message.from==='new','NFT mailbox crossed networks');
        check((await call('/nft/enroll',{category:fixture.macCategory})).body.error==='unknown category','NFT route accepted legacy category');
        check((await call('/enroll',{category:nft.macCategory})).body.error==='unknown category','legacy route accepted NFT category');
        check((await call('/badge-claim',{})).body.error==='NFT claims not enabled','legacy NFT route enabled');
    } finally {
        await rpc.shutdown();
        await Deno.remove(directory,{recursive:true});
    }
});
