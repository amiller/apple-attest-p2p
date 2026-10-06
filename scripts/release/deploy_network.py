#!/usr/bin/env python3
"""Deploy a separate V2 test network; never modify an existing deployment."""
import argparse,json,os,time
from pathlib import Path
from web3 import Web3
from eth_account import Account

ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--rpc',required=True)
p.add_argument('--build',type=Path,required=True)
p.add_argument('--out',type=Path,required=True)
p.add_argument('--activate',action='store_true',help='Enable admission immediately (otherwise deploy paused)')
p.add_argument('--category',type=int,choices=(3,6),default=6)
a=p.parse_args()
if a.out.exists():raise SystemExit('Output exists; refusing duplicate deployment')
w3=Web3(Web3.HTTPProvider(a.rpc,request_kwargs={'timeout':120}))
if w3.eth.chain_id not in (31337,84532):raise SystemExit('Test networks only')
account=Account.from_key(os.environ['PRIVATE_KEY'])
receipts=[]
def send(fn):
    gas=fn.estimate_gas({'from':account.address})
    tx=fn.build_transaction({'from':account.address,'nonce':w3.eth.get_transaction_count(account.address,'pending'),'gas':gas*2,'gasPrice':w3.eth.gas_price*2})
    receipt=w3.eth.wait_for_transaction_receipt(w3.eth.send_raw_transaction(account.sign_transaction(tx).raw_transaction),timeout=180)
    if receipt['status']!=1:raise RuntimeError('Deployment transaction reverted')
    receipts.append(receipt['transactionHash'].to_0x_hex())
    if w3.eth.chain_id==84532:time.sleep(4)
    return receipt

def contract(name,*args):
    artifact=json.loads((ROOT/'contracts/out'/f'{name}.sol'/f'{name}.json').read_text())
    factory=w3.eth.contract(abi=artifact['abi'],bytecode=artifact['bytecode']['object'])
    address=send(factory.constructor(*args))['contractAddress']
    return w3.eth.contract(address=address,abi=artifact['abi'])
cds=contract('CDRegistry')
build=json.loads(a.build.read_text())
b=lambda k:bytes.fromhex(build[k].removeprefix('0x'))
send(cds.functions.setBuild(b('cd'),b('page0'),b('ent'),build['linkeditCmd'],build['codeSigCmd']))
send(cds.functions.registerBuild(b('cd'),b('page0'),b('ent')))
demo=contract('DemoV2',account.address)
adapter=contract('AppleAttestRegistryV1',demo.address,cds.address,bytes.fromhex('61707061747465737400000000000000'),a.category,False)
family=b'apple-macos'.ljust(32,b'\0')
from eth_abi import encode
policy=Web3.keccak(encode(['address'],[cds.address]))
id=demo.functions.addCategory(family,policy,adapter.address,True).call({'from':account.address})
send(demo.functions.addCategory(family,policy,adapter.address,True))
send(demo.functions.setCategoryEnabled(id,True))
if a.activate:send(demo.functions.setPaused(False))
result={'protocolVersion':2,'chainId':w3.eth.chain_id,'admin':account.address,'DemoV1':demo.address,'macCDRegistry':cds.address,'macAdapter':adapter.address,'macCategory':Web3.to_hex(id),'DemoV1Artifact':'out/DemoV2.sol/DemoV2.json','CDRegistryArtifact':'out/CDRegistry.sol/CDRegistry.json','AdapterArtifact':'out/AppleAttestRegistryV1.sol/AppleAttestRegistryV1.json','transactions':receipts}
a.out.parent.mkdir(parents=True,exist_ok=True);a.out.write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
