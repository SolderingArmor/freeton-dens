#!/usr/bin/bash

# ================================================================================
#
AMOUNT_TONS=6000000000
GIVER="0:841288ed3b55d9cdafa806807f02a0ae0c169aa5edfe88a789a6482429756a94"
CODE=$(tvm_linker decode --tvc ../contracts/DnsRecord.tvc  | grep code: | cut -c 8-)
KEYS_FILE="keys1.json"
PUBKEY=$(cat $KEYS_FILE | grep public | cut -c 14-77)
ZERO_ADDRESS="0:0000000000000000000000000000000000000000000000000000000000000000"


LOCALNET="http://192.168.0.80"
DEVNET="https://net.ton.dev"
MAINNET="https://main.ton.dev"
NETWORK=$LOCALNET

echo "===================================================================================================="
echo "deploying $@"
echo "===================================================================================================="

DEPLOYER_ADDRESS=$(./get_deployer_address.sh $@)
DNS_ADDRESS=$(./get_domain_address.sh $@)
echo "DNS CONTRACT ADDRESS: $DNS_ADDRESS"

echo "Giving $AMOUNT_TONS TONs to $DEBOT_ADDRESS"
tonos-cli -u $NETWORK call --abi local_giver.abi.json $GIVER sendGrams "{\"dest\":\"$DEPLOYER_ADDRESS\",\"amount\":\"$AMOUNT_TONS\"}" > /dev/null

tonos-cli -u $NETWORK deploy ../contracts/DnsDeployer.tvc '{"ownerAddress":"'$ZERO_ADDRESS'", "ownerPubKey":"0x'$PUBKEY'", "regType":0}' --abi ../contracts/DnsDeployer.abi.json --sign $KEYS_FILE --wc 0
tonos-cli -u $NETWORK call $DEPLOYER_ADDRESS destroy '{"dest":"'$DNS_ADDRESS'"}' --sign $KEYS_FILE --abi ../contracts/DnsDeployer.abi.json

