#!/usr/bin/bash

# ================================================================================
#
CODE=$(tvm_linker decode --tvc ../contracts/DnsRecord.tvc  | grep code: | cut -c 8-)
KEYS_FILE="keys1.json"
PUBKEY=$(cat $KEYS_FILE | grep public | cut -c 14-77)
ZERO_ADDRESS="0:0000000000000000000000000000000000000000000000000000000000000000"

# ================================================================================
#
get_domain_address () {
    D1=$(bash convert_name.sh $@)
    echo $(tonos-cli genaddr --data '{"_dnsName":'$D1',"_code":"'$CODE'"}' ../contracts/DnsRecord.tvc ../contracts/DnsRecord.abi.json --setkey keysZERO.json --wc 0 --save | grep "Raw address:" | cut -c 14-)
}

# ================================================================================
#
get_domain_address $@
