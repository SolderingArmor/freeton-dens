pragma ton-solidity >= 0.35.0;
pragma AbiHeader time;
pragma AbiHeader pubkey;
pragma AbiHeader expire;

//================================================================================
//
import "DnsRecord.sol";

//================================================================================
//
contract DnsDeployer 
{
    TvmCell public static _code;
    uint256 _callerPubKey;

    //========================================
    //
    function calculateFutureAddress(bytes[] domain) private inline view returns (address, TvmCell)
    {
        TvmCell stateInit = tvm.buildStateInit({
            contr: DnsRecord,
            varInit: {
                _dnsName: domain,
                _code:    _code
            },
            code: _code
        });

        return (address(tvm.hash(stateInit)), stateInit);
    }

    function getDomainAddress(bytes[] name) external view returns (address)
    {
        (address addr, ) = calculateFutureAddress(name);
        return addr;
    }

    function destroy(address dest) external
    {
        require(_callerPubKey == msg.pubkey(), DNS.ERROR_MESSAGE_SENDER_IS_NOT_MY_OWNER);
        tvm.accept();
        selfdestruct(dest);
    }

    //========================================
    //
    constructor(bytes[] name, address ownerAddress, uint256 ownerPubKey, REG_TYPE regType) public 
    {
        require(name.length >= 1,       DNS.ERROR_DNS_NAME_EMPTY           );
        require(regType < REG_TYPE.NUM, DNS.ERROR_INVALID_REGISTRATION_TYPE);

        tvm.accept(); // need this because checkDnsNameValidity() is expensive
        _callerPubKey = msg.pubkey();
        require(DNS.checkDnsNameValidity(name) == true, DNS.ERROR_DNS_NAME_WRONG_NAME);
        
        (address addr, TvmCell stateInit) = calculateFutureAddress(name);
        address newAddress = new DnsRecord{stateInit: stateInit, value: 1 ton}(ownerAddress, ownerPubKey, regType);
    }
}

//================================================================================
//