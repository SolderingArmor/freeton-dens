#!/usr/bin/bash

# ================================================================================
#
#AMOUNT_TONS=6000000000
CODE=$(tvm_linker decode --tvc ../contracts/DnsRecord.tvc  | grep code: | cut -c 8-)
KEYS_FILE="keys1.json"
PUBKEY=$(cat $KEYS_FILE | grep public | cut -c 14-77)
ZERO_ADDRESS="0:0000000000000000000000000000000000000000000000000000000000000000"

echo "===================================================================================================="
echo "deploying $@"
echo "===================================================================================================="

DEPLOYER_ADDRESS=$(./get_deployer_address.sh $@)
DNS_ADDRESS=$(./get_domain_address $@)
echo "DNS CONTRACT ADDRESS: $DNS_ADDRESS"

tonos-cli deploy ../contracts/DnsDeployer.tvc '{"ownerAddress":"'$ZERO_ADDRESS'", "ownerPubKey":"0x'$PUBKEY'", "regType":0}' --abi ../contracts/DnsDeployer.abi.json --sign $KEYS_FILE --wc 0
tonos-cli call $DEPLOYER_ADDRESS destroy '{"dest":"'$DNS_ADDRESS'"}' --sign $KEYS_FILE --abi ../contracts/DnsDeployer.abi.json

