pragma ton-solidity >= 0.35.0;
pragma AbiHeader time;
pragma AbiHeader pubkey;
pragma AbiHeader expire;

//================================================================================
//
import "../interfaces/IDnsRecord.sol";

//================================================================================
//
contract DnsRecord is IDnsRecord
{
    //========================================
    // Events
    event ownerChanged(uint dt, address oldOwner, address newOwner);
    event registratioRequested(uint dt, bytes[] name);
    
    //========================================
    // Constants
    address constant addressZero = address.makeAddrStd(0, 0); //
    uint32  constant tenDays     = 60 * 60 * 24 * 10;         // 10 days in seconds
    uint32  constant sixtyDays   = tenDays * 6;               // 60 days in seconds

    // Mappings
    //
    bytes[][] public _domainRegistrationRequests; // All registration reqeusts

    // Variables
    uint256    public        _ownerPubKey     = 0;
    address    public        _ownerAddress    = addressZero;
    REG_TYPE   public        _regType         = REG_TYPE.FFA;
    bytes[]    public static _dnsName;
    TvmCell    public static _code;
    address    public        _endpointAddress = addressZero; // this is what DNS is for;
    uint32     public        _expirationDate  = 0;
    REG_RESULT public        _lastRegResult   = REG_RESULT.NONE;

    //========================================
    // Modifiers
    modifier onlyOwner 
    {
        // Owner can make changes only after registration process is completed;
        require(_ownerPubKey == msg.pubkey() && _ownerAddress == msg.sender, DNS.ERROR_MESSAGE_SENDER_IS_NOT_MY_OWNER);
        require(_lastRegResult == REG_RESULT.APPROVED,                       DNS.ERROR_REGISTRATION_INCOMPLETE       );
        isExpired();
        _;
    }

    //========================================
    //
    constructor(address ownerAddress, uint256 ownerPubKey, REG_TYPE regType) public 
    {
        require(_dnsName.length >= 1,   DNS.ERROR_DNS_NAME_EMPTY           );
        require(regType < REG_TYPE.NUM, DNS.ERROR_INVALID_REGISTRATION_TYPE);

        tvm.accept(); // need this because checkDnsNameValidity() is expensive
        require(DNS.checkDnsNameValidity(_dnsName) == true, DNS.ERROR_DNS_NAME_WRONG_NAME);

        _ownerPubKey  = ownerPubKey;
        _ownerAddress = ownerAddress;

        if(_dnsName.length == 1) // if it is a ROOT domain name
        {
            // Root domains won't need approval, callback right away
            callback_RequestRegistration(REG_RESULT.APPROVED);
        }
        else if(_dnsName.length > 1) // NOT a ROOT domain name
        {
            // claimExpired does the same thing as initial registration, no point in duplicating code
            claimExpired(ownerAddress, ownerPubKey);
        }
    }

    //========================================
    //
    function getEndpointAddress() external override returns (address)
    {
        isExpired();
        return _endpointAddress;
    }

    //========================================
    //
    function changeEndpointAddress(address newAddress) external override onlyOwner
    {
        tvm.accept();
        _endpointAddress = newAddress;
    }

    //========================================
    //
    function changeOwnership(address newOwnerAddress, uint256 newOwnerPubKey) external override onlyOwner
    {
        tvm.accept();
        _ownerPubKey  = newOwnerPubKey;
        _ownerAddress = newOwnerAddress;
    }

    //========================================
    //
    /// @dev TODO: here "external" was purposely changed to "public", otherwise you get the following error:
    ///      Error: Undeclared identifier. "isExpired" is not (or not yet) visible at this point.
    ///      The fix is coming: https://github.com/tonlabs/TON-Solidity-Compiler/issues/36
    function isExpired() public override returns (bool)
    {
        if(_lastRegResult == REG_RESULT.EXPIRED)
        {
            return true;
        }

        bool expired = (now > _expirationDate);
        if(expired)
        {
            tvm.accept();
            _ownerAddress  = addressZero;
            _ownerPubKey   = 0;
            _lastRegResult = REG_RESULT.EXPIRED;
        }

        return (expired);
    }

    //========================================
    //
    /// @dev TODO: here "external" was purposely changed to "public", otherwise you get the following error:
    ///      Error: Undeclared identifier. "claimExpired" is not (or not yet) visible at this point.
    ///      The fix is coming: https://github.com/tonlabs/TON-Solidity-Compiler/issues/36
    function claimExpired(address newOwnerAddress, uint256 newOwnerPubKey) public override
    {
        require(isExpired(), DNS.ERROR_DOMAIN_IS_NOT_EXPIRED);
        _lastRegResult = REG_RESULT.PENDING;
            
        bytes[] parentName;
        for(uint i = 0; i < _dnsName.length - 1; i ++)
        {
            parentName.push(_dnsName[i]);
        }

        (address parent, ) = calculateFutureAddress(parentName);
        IDnsRecord(parent).requestRegistration(_dnsName, newOwnerAddress, newOwnerPubKey);
    }

    //========================================
    //
    function prolongate() external override onlyOwner
    {
        tvm.accept();
        bool expired = isExpired();

        //
        if(expired)
        {
            // Throw
            require(false, DNS.ERROR_DOMAIN_EXPIRED);
        }

        //
        if(now <= _expirationDate && now >= _expirationDate - tenDays)
        {
            _expirationDate += sixtyDays;
            return;
        }

        // Throw
        require(false, DNS.ERROR_TOO_EARLY_TO_PROLONGATE);
    }

    //========================================
    //
    function setRegistrationType(REG_TYPE newType) external override onlyOwner
    {
        require(newType < REG_TYPE.NUM, DNS.ERROR_INVALID_REGISTRATION_TYPE);

        tvm.accept();
        _regType = newType;
    }

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

    //========================================
    //
    function arraysEqual(bytes[] array1, bytes[] array2) private inline pure returns (bool)
    {
        if(array1.length != array2.length)
        {
            return false;
        }

        for(uint i = 0; i < array1.length; i++)
        {
            if(tvm.hash(array1[i]) != tvm.hash(array2[i]))
            {
                return false;
            }
        }

        return true;
    }

    //========================================
    //
    function requestRegistration(bytes[] name, address ownerAddress, uint256 ownerPubKey) external override 
    {
        REG_RESULT result;
             if(_regType == REG_TYPE.FFA)    {    result = REG_RESULT.APPROVED;    }
        else if(_regType == REG_TYPE.DENY)   {    result = REG_RESULT.DENIED;      }
        else if(_regType == REG_TYPE.REQUEST)
        {
            //_domainRegistrationRequests[tvm.hash(name)] = name;
            _domainRegistrationRequests.push(name);

            emit registratioRequested(now, name);
            result = REG_RESULT.PENDING;     
        }
        else if(_regType == REG_TYPE.OWNER)
        {
            bool ownerCalled = (ownerPubKey == _ownerPubKey && ownerAddress == _ownerAddress);
            result = ownerCalled ? REG_RESULT.APPROVED : REG_RESULT.DENIED;            
        }

        IDnsRecord(msg.sender).callback_RequestRegistration(result);
    }

    //========================================
    //
    /// @dev TODO: here "external" was purposely changed to "public", otherwise you get the following error:
    ///      Error: Undeclared identifier. "callback_RequestRegistration" is not (or not yet) visible at this point.
    ///      The fix is coming: https://github.com/tonlabs/TON-Solidity-Compiler/issues/36
    function callback_RequestRegistration(REG_RESULT result) public override 
    {
        _lastRegResult = result;
        
        if(result == REG_RESULT.APPROVED)
        {
            _expirationDate = now + sixtyDays;
        }
        else if(result == REG_RESULT.PENDING)
        {
            _lastRegResult = result;
        }
        else if(result == REG_RESULT.DENIED)
        {
            _ownerPubKey    = 0;
            _ownerAddress   = addressZero;
            _expirationDate = 0;
        }
    }

    //========================================
    //
    function getDomainAddress(bytes[] name) external view override returns (address)
    {
        (address addr, ) = calculateFutureAddress(name);
        return addr;
    }

    //========================================
    //
    function approveRegistration(bytes[] name) external override 
    {
        isExpired();
        
        tvm.accept();

        (address addr, ) = calculateFutureAddress(name);
        
        for(uint256 i = 0; i < _domainRegistrationRequests.length; i++)
        {
            if(arraysEqual(_domainRegistrationRequests[i], name))
            {
                IDnsRecord(addr).callback_RequestRegistration(REG_RESULT.APPROVED);
                delete _domainRegistrationRequests[i];
                return;
            }
        }
    }

    //========================================
    //
    function approveRegistrationAll() external override 
    {
        isExpired();
        
        tvm.accept();

        for(bytes[] i : _domainRegistrationRequests)
        {
            (address addr, ) = calculateFutureAddress(i);
            IDnsRecord(addr).callback_RequestRegistration(REG_RESULT.APPROVED);
        }
        delete _domainRegistrationRequests;
    }
    
    //========================================
    //
    function denyRegistration(bytes[] name) external override 
    {
        isExpired();
        
        tvm.accept();

        (address addr, ) = calculateFutureAddress(name);
        
        for(uint256 i = 0; i < _domainRegistrationRequests.length; i++)
        {
            if(arraysEqual(_domainRegistrationRequests[i], name))
            {
                IDnsRecord(addr).callback_RequestRegistration(REG_RESULT.DENIED);
                delete _domainRegistrationRequests[i];
                return;
            }
        }
    }
    
    //========================================
    //
    function denyRegistrationAll() external override 
    {
        isExpired();
        
        tvm.accept();
        
        for(bytes[] i : _domainRegistrationRequests)
        {
            (address addr, ) = calculateFutureAddress(i);
            IDnsRecord(addr).callback_RequestRegistration(REG_RESULT.DENIED);
        }
        delete _domainRegistrationRequests;
    }
    
}

//================================================================================
//