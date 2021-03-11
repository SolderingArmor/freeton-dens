pragma ton-solidity >= 0.38.0;
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
    bytes[] public static _dnsName;
    uint256 public        _callerPubKey;

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

    function destroy(address dest) external
    {
        require(_callerPubKey == msg.pubkey(), DNS.ERROR_MESSAGE_SENDER_IS_NOT_MY_OWNER);

        tvm.accept();
        selfdestruct(dest);
    }

    //========================================
    //
    constructor(address ownerAddress, uint256 ownerPubKey, REG_TYPE regType) public 
    {
        require(_dnsName.length >= 1,   DNS.ERROR_DNS_NAME_EMPTY           );
        require(_dnsName.length <= 4,   DNS.ERROR_TOO_MANY_SUBDOMAINS      );
        require(regType < REG_TYPE.NUM, DNS.ERROR_INVALID_REGISTRATION_TYPE);

        tvm.accept(); // need this because checkDnsNameValidity() is expensive
        _callerPubKey = msg.pubkey();
        require(DNS.checkDnsNameValidity(_dnsName) == true, DNS.ERROR_WRONG_DNS_NAME);
        tvm.accept(); // reset gas value
        (address addr, TvmCell stateInit) = calculateFutureAddress(_dnsName);
        //address newAddress = new DnsRecord{stateInit: stateInit, value: address(this).balance / 2, flag: 0}(ownerAddress, ownerPubKey, regType);
        address newAddress = new DnsRecord{stateInit: stateInit, value: address(this).balance - 0.2 ton, flag: 0}(ownerAddress, ownerPubKey, regType);
    }
}

//================================================================================
//