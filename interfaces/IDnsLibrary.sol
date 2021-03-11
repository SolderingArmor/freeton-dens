pragma ton-solidity >= 0.38.0;
pragma AbiHeader time;
pragma AbiHeader pubkey;
pragma AbiHeader expire;

//================================================================================
//
library DNS
{
    //========================================
    // Error codes
    uint constant ERROR_MESSAGE_SENDER_IS_NOT_MY_OWNER = 100;
    uint constant ERROR_MESSAGE_SENDER_IS_NOT_MY_ROOT  = 101;
    uint constant ERROR_EITHER_ADDRESS_OR_PUBKEY       = 102;
    uint constant ERROR_REGISTRATION_INCOMPLETE        = 103;
    uint constant ERROR_DNS_WRONG_TYPE                 = 201;
    uint constant ERROR_DNS_NAME_EMPTY                 = 202;
    uint constant ERROR_WRONG_DNS_NAME                 = 203;
    uint constant ERROR_DNS_NAME_TOO_LONG              = 204;
    uint constant ERROR_TOO_MANY_SUBDOMAINS            = 205;
    uint constant ERROR_DOMAIN_DENIED                  = 206;
    uint constant ERROR_DOMAIN_EXPIRED                 = 207;
    uint constant ERROR_DOMAIN_NOT_EXPIRED             = 208;
    uint constant ERROR_TOO_EARLY_TO_PROLONGATE        = 209;
    uint constant ERROR_INVALID_REGISTRATION_TYPE      = 210;
    uint constant ERROR_NOT_ENOUGH_MONEY               = 211;
    uint constant ERROR_EXTERNAL_CALLER                = 212;
    
    //========================================
    // Only NUMBERS and LOWERCASE LETTERS are allowed;
    // Maximum depth (subdomains)  = 4;
    // Maximum length of 1 segment = 63 symbols;
    function checkDnsNameValidity(bytes[] name) internal pure returns (bool)
    {
        require(name.length >= 1, DNS.ERROR_DNS_NAME_EMPTY     );
        require(name.length <= 4, DNS.ERROR_TOO_MANY_SUBDOMAINS);

        for(uint256 item = 0; item < name.length; item++)
        {            
            require(name[item].length <= 63, DNS.ERROR_DNS_NAME_TOO_LONG);

            for(uint256 letter = 0; letter < name[item].length; letter++)
            {
                bytes1 char = name[item][letter];                
                bool numbers = (char >= 0x30 && char <= 0x39);
                bool lower   = (char >= 0x61 && char <= 0x7A);

                if(!numbers && !lower)
                {
                    return false;
                }
            }
        }

        return true;
    }

    //========================================
    // 
    function arraysEqual(bytes[] array1, bytes[] array2) internal inline pure returns (bool)
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

}

//================================================================================
//