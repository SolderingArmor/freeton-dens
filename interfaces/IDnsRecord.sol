pragma ton-solidity >= 0.35.0;
pragma AbiHeader expire;

//================================================================================
// 
enum REG_TYPE
{
    FFA,     // Free For All, anyone can register a subdomain;
    REQUEST, // A reques is sent to a parent domain, parent domain owner needs to manually approve or reject a request;
    OWNER,   // Only owner can register a subdomain, all other request are denied;
    DENY,     // All requests are denied;
    NUM
}

enum REG_RESULT
{
    NONE,     // this
    PENDING,  // is
    APPROVED, // self
    DENIED,   // explanatory
    EXPIRED,
    NUM
}


//================================================================================
//
library DNS
{
    // Error codes
    uint constant ERROR_MESSAGE_SENDER_IS_NOT_MY_OWNER = 100;
    uint constant ERROR_REGISTRATION_INCOMPLETE        = 101;
    uint constant ERROR_DNS_WRONG_TYPE                 = 201;
    uint constant ERROR_DNS_NAME_EMPTY                 = 202;
    uint constant ERROR_DNS_NAME_WRONG_NAME            = 203;
    uint constant ERROR_DOMAIN_EXPIRED                 = 204;
    uint constant ERROR_DOMAIN_IS_NOT_EXPIRED          = 205;
    uint constant ERROR_TOO_EARLY_TO_PROLONGATE        = 206;
    uint constant ERROR_INVALID_REGISTRATION_TYPE      = 207;
    
    function checkDnsNameValidity(bytes[] name) internal pure returns (bool)
    {
        for(uint256 item = 0; item < name.length; item++)
        {            
            for(uint256 letter = 0; letter < name[item].length; letter++)
            {
                bytes1 char = name[item][letter];
                
                bool numbers = (char >= 0x30 && char <= 0x39);
                bool upper   = (char >= 0x41 && char <= 0x5A);
                bool lower   = (char >= 0x61 && char <= 0x7A);

                if(!numbers && !upper && !lower)
                {
                    return false;
                }
            }
        }

        return true;
    }
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
    
    /// @notice 00000000
    ///
    /// @param newType - 0000;
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
    //
    function claimExpired(address newOwnerAddress, uint256 newOwnerPubKey) external;
    
    /// @notice 00000000
    ///
    /// @param name         - 0000;
    /// @param ownerAddress - 0000;
    /// @param ownerPubKey  - 0000;
    //
    function requestRegistration(bytes[] name, address ownerAddress, uint256 ownerPubKey) external; // can call however times needed
    
    /// @notice 00000000
    ///
    /// @param result - 0000;
    //
    function callback_RequestRegistration(REG_RESULT result) external;

    //========================================
    // Registration
    function getDomainAddress(bytes[] name) external view returns (address);

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
}

//================================================================================
// 
