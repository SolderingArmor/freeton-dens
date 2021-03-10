#!/usr/bin/bash

# ================================================================================
#
CODE=$(tvm_linker decode --tvc ../contracts/DnsRecord.tvc  | grep code: | cut -c 8-)
KEYS_FILE="keys1.json"
PUBKEY=$(cat $KEYS_FILE | grep public | cut -c 14-77)
ZERO_ADDRESS="0:0000000000000000000000000000000000000000000000000000000000000000"

# ================================================================================
#
D1=$(./convert_name.sh $@)
DEPLOYER_ADDRESS=$(tonos-cli genaddr --data '{"_dnsName":'$D1',"_code":"'$CODE'"}' ../contracts/DnsDeployer.tvc ../contracts/DnsDeployer.abi.json --setkey $KEYS_FILE --wc 0 --save | grep "Raw address:" | cut -c 14-)
echo $DEPLOYER_ADDRESS
