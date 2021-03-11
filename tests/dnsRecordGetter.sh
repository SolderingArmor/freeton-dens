#!/usr/bin/bash

# ================================================================================
#
#AMOUNT_TONS=6000000000
GIVER="0:841288ed3b55d9cdafa806807f02a0ae0c169aa5edfe88a789a6482429756a94"
CODE=$(tvm_linker decode --tvc ../contracts/DnsRecord.tvc  | grep code: | cut -c 8-)
KEYS_FILE="keys1.json"
PUBKEY=$(cat $KEYS_FILE | grep public | cut -c 14-77)
ZERO_ADDRESS="0:0000000000000000000000000000000000000000000000000000000000000000"


LOCALNET="http://192.168.0.80"
DEVNET="https://net.ton.dev"
MAINNET="https://main.ton.dev"
NETWORK=$LOCALNET

GETTER_NAME=$1
shift

echo "===================================================================================================="
echo "Getting $GETTER_NAME from $@"
echo "===================================================================================================="

DNS_ADDRESS=$(./get_domain_address.sh $@)
echo "DNS CONTRACT ADDRESS: $DNS_ADDRESS"

tonos-cli -u $NETWORK run $DNS_ADDRESS $GETTER_NAME '{}' --abi ../contracts/DnsRecord.abi.json | awk '/Result: {/,/}/'
