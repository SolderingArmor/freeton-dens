pragma ton-solidity >= 0.38.0;
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
    event registrationRequested(uint dt, bytes[] name);
    
    //========================================
    // Constants
    address constant addressZero = address.makeAddrStd(0, 0); //
    uint32  constant tenDays     = 60 * 60 * 24 * 10;         // 10 days in seconds
    uint32  constant ninetyDays  = tenDays * 9;               // 90 days in seconds

    // Mappings
    //
    bytes[][] public _domainRegistrationRequests; // All registration reqeusts

    // Variables
    uint256    public        _ownerPubKey       = 0;
    address    public        _ownerAddress      = addressZero;
    REG_TYPE   public        _regType           = REG_TYPE.FFA;
    bytes[]    public static _dnsName;
    TvmCell    public static _code;
    address    public        _endpointAddress   = addressZero; // this is what DNS is for;
    uint32     public        _expirationDate    = 0;
    REG_RESULT public        _lastRegResult     = REG_RESULT.NONE;
    uint128    public        _subdomainRegPrice = 0;

    //========================================
    // Modifiers
    modifier onlyOwner 
    {
        // Owner can make changes only after registration process is completed;
        bool byPubKey  = (_ownerPubKey == msg.pubkey() && _ownerAddress == addressZero);
        bool byAddress = (_ownerPubKey == 0            && _ownerAddress == msg.sender );

        require(byPubKey || byAddress, DNS.ERROR_MESSAGE_SENDER_IS_NOT_MY_OWNER);
        _;
    }

    modifier notExpired 
    {
        require(!isExpired(), DNS.ERROR_DOMAIN_EXPIRED);
        _;
    }

    //========================================
    //
    constructor(address ownerAddress, uint256 ownerPubKey, REG_TYPE regType) public 
    {
        require(_dnsName.length >= 1,   DNS.ERROR_DNS_NAME_EMPTY           );
        require(_dnsName.length <= 4,   DNS.ERROR_TOO_MANY_SUBDOMAINS      );
        require(regType < REG_TYPE.NUM, DNS.ERROR_INVALID_REGISTRATION_TYPE);

        tvm.accept(); // need this because checkDnsNameValidity() is expensive
        require(DNS.checkDnsNameValidity(_dnsName) == true, DNS.ERROR_WRONG_DNS_NAME);
        
        // Reset the gas
        tvm.accept(); 
        
        _ownerPubKey    = ownerPubKey;
        _ownerAddress   = ownerAddress;
        _lastRegResult  = REG_RESULT.PENDING;
        _expirationDate = now + tenDays; // when claiming domain is taken for 10 days to wait for registration to be completed;
        
        // if it is a ROOT domain name
        if(_dnsName.length == 1) 
        {
            // Root domains won't need approval, internal callback right away
            _callback_RegistrationRequest(REG_RESULT.APPROVED);
        }
        // else{}
        // For 2+ level subdomains you need to call "sendRegistrationRequest()" manually 
        // (because you need to know registration terms of the parent Record fist, not to waste money);
    }

    //========================================
    //
    function getEndpointAddress() external override returns (address)
    {
        return _endpointAddress;
    }

    //========================================
    //
    function changeEndpointAddress(address newAddress) external override onlyOwner notExpired
    {
        tvm.accept();
        _endpointAddress = newAddress;
    }

    //========================================
    //
    function changeOwnership(address newOwnerAddress, uint256 newOwnerPubKey) external override onlyOwner notExpired
    {
        bool byPubKey  = (newOwnerPubKey != 0 && newOwnerAddress == addressZero);
        bool byAddress = (newOwnerPubKey == 0 && newOwnerAddress != addressZero);

        require(byPubKey || byAddress, DNS.ERROR_EITHER_ADDRESS_OR_PUBKEY);
        
        tvm.accept();
        _ownerPubKey     = newOwnerPubKey;
        _ownerAddress    = newOwnerAddress;
        _endpointAddress = addressZero;
    }

    //========================================
    //
    /// @dev TODO: here "external" was purposely changed to "public", otherwise you get the following error:
    ///      Error: Undeclared identifier. "isExpired" is not (or not yet) visible at this point.
    ///      The fix is coming: https://github.com/tonlabs/TON-Solidity-Compiler/issues/36
    function isExpired() public override returns (bool)
    {
        return (now > _expirationDate);
    }

    //========================================
    //
    /// @dev TODO: here "external" was purposely changed to "public", otherwise you get the following error:
    ///      Error: Undeclared identifier. "claimExpired" is not (or not yet) visible at this point.
    ///      The fix is coming: https://github.com/tonlabs/TON-Solidity-Compiler/issues/36
    function claimExpired(address newOwnerAddress, uint256 newOwnerPubKey, REG_TYPE regType) public override
    {
        require(isExpired() || _lastRegResult == REG_RESULT.DENIED, DNS.ERROR_DOMAIN_NOT_EXPIRED);

        tvm.accept();

        emit ownerChanged(now, _ownerAddress, newOwnerAddress);

        _lastRegResult  = REG_RESULT.PENDING;
        _ownerAddress   = newOwnerAddress;
        _ownerPubKey    = newOwnerPubKey;
        _regType        = regType;
        _expirationDate = now + tenDays; // when claiming domain is taken for 10 days to wait for registration to be completed;
        
        // if it is a ROOT domain name
        if(_dnsName.length == 1) 
        {
            // Root domains won't need approval, internal callback right away
            _callback_RegistrationRequest(REG_RESULT.APPROVED);
        }
    }

    //========================================
    //
    function prolongate() external override onlyOwner notExpired
    {
        //_checkExpired();
        
        tvm.accept();
        //
        if(now <= _expirationDate && now >= _expirationDate - tenDays)
        {
            _expirationDate += ninetyDays;
            return;
        }

        // Throw
        require(false, DNS.ERROR_TOO_EARLY_TO_PROLONGATE);
    }

    //========================================
    //
    function setRegistrationType(REG_TYPE newType) external override onlyOwner notExpired
    {
        require(newType < REG_TYPE.NUM, DNS.ERROR_INVALID_REGISTRATION_TYPE);
        //_checkExpired();
        
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
    function calculateDomainAddress(bytes[] name) external view override returns (address)
    {
        (address addr, ) = calculateFutureAddress(name);
        return addr;
    }

    //========================================
    // 
    function _getParentName(bytes[] name) internal pure returns (bytes[])
    {
        if(name.length == 1)
        {
            return name;
        }
        
        bytes[] parentName;
        for(uint i = 0; i < name.length - 1; i ++)
        {
            parentName.push(name[i]);
        }

        return parentName;
    }

    //========================================
    //
    /// @dev TODO: here "external" was purposely changed to "public", otherwise you get the following error:
    ///      Error: Undeclared identifier. "sendRegistrationRequest" is not (or not yet) visible at this point.
    ///      The fix is coming: https://github.com/tonlabs/TON-Solidity-Compiler/issues/36
    function sendRegistrationRequest(uint128 tonsToInclude) public override
    {
        require(_dnsName.length > 1,                                                                   DNS.ERROR_WRONG_DNS_NAME);
        require(_lastRegResult == REG_RESULT.NOT_ENOUGH_MONEY || _lastRegResult == REG_RESULT.PENDING, DNS.ERROR_DOMAIN_DENIED );

        tvm.accept();
        uint128 tonsWithGas = tonsToInclude + 0.2 ton;

        bytes[] parentName = _getParentName(_dnsName);
        (address parent, ) = calculateFutureAddress(parentName);
        IDnsRecord(parent).receiveRegistrationRequest{value: tonsWithGas, callback: IDnsRecord.callback_RegistrationRequest}(_dnsName, _ownerAddress, _ownerPubKey);
    }

    //========================================
    //
    function receiveRegistrationRequest(bytes[] name, address ownerAddress, uint256 ownerPubKey) external responsible override returns (REG_RESULT)
    {
        require(msg.pubkey() == 0, DNS.ERROR_EXTERNAL_CALLER );
        require(msg.value     > 0, DNS.ERROR_NOT_ENOUGH_MONEY);
        tvm.accept();

        REG_RESULT result;
             if(_regType == REG_TYPE.FFA)    {    result = REG_RESULT.APPROVED;    }
        else if(_regType == REG_TYPE.DENY)   {    result = REG_RESULT.DENIED;      }
        else if(_regType == REG_TYPE.REQUEST)
        {
            // TODO: do not duplicate if the same domain requested registration 2+ times
            //       spammers gonna spam;
            _domainRegistrationRequests.push(name);

            emit registrationRequested(now, name);
            result = REG_RESULT.PENDING;     
        }
        else if(_regType == REG_TYPE.MONEY)
        {
            result = (msg.value >= _subdomainRegPrice ? REG_RESULT.APPROVED : REG_RESULT.NOT_ENOUGH_MONEY);
            if(result == REG_RESULT.NOT_ENOUGH_MONEY)
            {
                // Registration failed, return the change
                return{value: 0, flag: 64}(result);
            }
        }
        else if(_regType == REG_TYPE.OWNER)
        {
            bool ownerCalled = (ownerPubKey == _ownerPubKey && ownerAddress == _ownerAddress);
            result = ownerCalled ? REG_RESULT.APPROVED : REG_RESULT.DENIED;            
        }

        return{value: 0.1 ton, flag: 0}(result);
    }

    //========================================
    //
    /// @dev TODO: here "external" was purposely changed to "public", otherwise you get the following error:
    ///      Error: Undeclared identifier. "callback_RegistrationRequest" is not (or not yet) visible at this point.
    ///      The fix is coming: https://github.com/tonlabs/TON-Solidity-Compiler/issues/36
    function callback_RegistrationRequest(REG_RESULT result) public override 
    {
        require(_dnsName.length > 1, DNS.ERROR_WRONG_DNS_NAME);
        tvm.accept();
        
        bytes[] parentName = _getParentName(_dnsName);
        (address parent, ) = calculateFutureAddress(parentName);
        require(msg.sender == parent, DNS.ERROR_MESSAGE_SENDER_IS_NOT_MY_ROOT);
        
        _callback_RegistrationRequest(result);
    }

    function _callback_RegistrationRequest(REG_RESULT result) internal
    {
        tvm.accept();
        
        _lastRegResult = result;
        
        if(result == REG_RESULT.APPROVED)
        {
            _expirationDate = now + ninetyDays;
        }
        else if(result == REG_RESULT.PENDING)
        {
            //
        }
        else if(result == REG_RESULT.DENIED)
        {
            _ownerPubKey    = 0;
            _ownerAddress   = addressZero;
            _expirationDate = 0;
        }
        else if(result == REG_RESULT.NOT_ENOUGH_MONEY)
        {
            //
        }
    }


    //========================================
    //
    function approveRegistration(bytes[] name) external override onlyOwner notExpired
    {
        //_checkExpired();
                
        tvm.accept();

        (address addr, ) = calculateFutureAddress(name);
        
        for(uint256 i = 0; i < _domainRegistrationRequests.length; i++)
        {
            if(DNS.arraysEqual(_domainRegistrationRequests[i], name))
            {
                IDnsRecord(addr).callback_RegistrationRequest(REG_RESULT.APPROVED);
                delete _domainRegistrationRequests[i];
                return;
            }
        }
    }

    //========================================
    //
    function approveRegistrationAll() external override onlyOwner notExpired
    {
        //_checkExpired();
                
        tvm.accept();

        for(bytes[] i : _domainRegistrationRequests)
        {
            (address addr, ) = calculateFutureAddress(i);
            IDnsRecord(addr).callback_RegistrationRequest(REG_RESULT.APPROVED);
        }
        delete _domainRegistrationRequests;
    }
    
    //========================================
    //
    function denyRegistration(bytes[] name) external override onlyOwner notExpired
    {
        //_checkExpired();
        
        tvm.accept();

        (address addr, ) = calculateFutureAddress(name);
        
        for(uint256 i = 0; i < _domainRegistrationRequests.length; i++)
        {
            if(DNS.arraysEqual(_domainRegistrationRequests[i], name))
            {
                IDnsRecord(addr).callback_RegistrationRequest(REG_RESULT.DENIED);
                delete _domainRegistrationRequests[i];
                return;
            }
        }
    }
    
    //========================================
    //
    function denyRegistrationAll() external override onlyOwner notExpired
    {
        //_checkExpired();
        
        tvm.accept();
        
        for(bytes[] i : _domainRegistrationRequests)
        {
            (address addr, ) = calculateFutureAddress(i);
            IDnsRecord(addr).callback_RegistrationRequest(REG_RESULT.DENIED);
        }
        delete _domainRegistrationRequests;
    }

    //========================================
    //
    function setSubdomainRegPrice(uint128 price) external override onlyOwner notExpired
    {
        //_checkExpired();
        
        tvm.accept();

        _subdomainRegPrice = price;
    }

    //========================================
    //
    function withdrawBalance(uint128 amount, address dest) external override onlyOwner notExpired
    {
        //_checkExpired();
        
        tvm.accept();

        dest.transfer(amount, false);
    }
    
}

//================================================================================
//