pragma ton-solidity >= 0.38.0;
pragma AbiHeader time;
pragma AbiHeader pubkey;
pragma AbiHeader expire;

//================================================================================
// 
import "../interfaces/IDnsLibrary.sol";

//================================================================================
// 
enum REG_TYPE
{
    FFA,     // Free For All, anyone can register a subdomain;
    REQUEST, // A request is sent to a parent domain, parent domain owner needs to manually approve or reject a request;
    MONEY,   // Registration is like FFA BUT you need to attach enough money (configurable by parent domain);
    OWNER,   // Only owner can register a subdomain, all other request are denied;
    DENY,    // All requests are denied;
    NUM
}

enum REG_RESULT
{
    NONE,             // 
    PENDING,          // Either root domain needs to manually approve the registration, or root domain doesn't exist; did you check that?
    APPROVED,         // Cool;
    DENIED,           // Root domain denies the registration (either automatically or manually), try again later;
    NOT_ENOUGH_MONEY, // Root domain requires more money to send;
    NUM
}

//================================================================================
// 
interface IDnsRecord
{
    //========================================
    // Gets

    /// @notice Get the endpoint address that DeNS record keeps;
    //
    function getEndpointAddress() external returns (address);
    
    /// @notice Check if this DeNS Record has expired;
    //
    function isExpired() external returns (bool);
    
    /// @notice Get address of any domain;
    ///
    /// @param name - domain name;
    //
    function calculateDomainAddress(bytes[] name) external view returns (address);

    //========================================
    // Sets
    /// @notice Change the endpoint address that DeNS record keeps;
    ///
    /// @param newAddress - new target address of this DeNS;
    //
    function changeEndpointAddress(address newAddress) external;
    
    /// @notice Change the owner;
    ///
    /// @param newOwnerAddress - address of a new owner; can be 0;
    /// @param newOwnerPubKey  - pubkey  of a new owner; can be (0, 0);
    ///
    /// @dev If you set both newOwnerAddress and newOwnerPubKey to 0, you will loose ownership of the domain!
    //
    function changeOwnership(address newOwnerAddress, uint256 newOwnerPubKey) external;
    
    /// @notice Change sub-domain registration type;
    ///
    /// @param newType - new type;
    //
    function setRegistrationType(REG_TYPE newType) external;

    //========================================
    // Registration

    /// @notice Prolongate the domain; only owner can call this and only 10 or less days prior to expiration;
    //
    function prolongate() external;
    
    /// @notice Claim an expired DeNS Record; claiming is the same as registering new one, except you don't deploy;
    ///
    /// @param newOwnerAddress - address of a new owner; can be 0;
    /// @param newOwnerPubKey  - pubkey  of a new owner; can be (0, 0);
    /// @param regType         - new registration type;
    //
    function claimExpired(address newOwnerAddress, uint256 newOwnerPubKey, REG_TYPE regType) external;
    
    /// @notice Send a registration request to a parent DomainRecord;
    ///         Can be called however times needed;
    ///         Parent domain won't return you ANY change, attach TONs carefully;
    ///
    /// @param tonsToInclude - TONs to include in message value; TONs need to be present on this account when sending;
    ///                        extra TONs are treated as tip;
    //
    function sendRegistrationRequest(uint128 tonsToInclude) external; 
    
    /// @notice Receive registration request from a sub-domain;
    ///
    /// @param name         - sub-domain name;
    /// @param ownerAddress - address of a new owner;
    /// @param ownerPubKey  - pubkey  of a new owner;
    //
    function receiveRegistrationRequest(bytes[] name, address ownerAddress, uint256 ownerPubKey) external responsible returns (REG_RESULT);
    
    /// @notice Callback received from parent domain with registration result;
    ///
    /// @param result - registration result;
    //
    function callback_RegistrationRequest(REG_RESULT result) external;

    //========================================
    // Sub-domain management

    /// @notice Approve registration of a specific sub-domain;
    ///
    /// @param name - full domain name;
    //
    function approveRegistration(bytes[] name) external;
    
    /// @notice Approve registration of all pending sub-domains;
    //
    function approveRegistrationAll() external;
    
    /// @notice Deny registration of a specific sub-domain;
    ///
    /// @param name - full domain name;
    //
    function denyRegistration(bytes[] name) external;
        
    /// @notice Deny registration of all pending sub-domains;
    //
    function denyRegistrationAll() external;    

    /// @notice Set sub-domain registration price;
    ///
    /// @param price - new registration price;
    //
    function setSubdomainRegPrice(uint128 price) external;
    
    //========================================
    // Misc

    /// @notice Withdraw some balance;
    ///
    /// @param amount - amount in nanotons;
    /// @param dest   - money destination;
    //
    function withdrawBalance(uint128 amount, address dest) external;
}

//================================================================================
// 
