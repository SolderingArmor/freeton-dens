# ! IMPORTANT !
This repo is kept only as history, development is continued in the following repo: https://github.com/laugual/dens-v2

Original idea and architecture are preserved, but a lot of new perks and features are added.

# FreeTON DeNS

No more copying and pasting long addresses. Use DeNS names to store all your addresses in a human-readable way!

## Key DeNS features:

* SIMPLICITY! Only one contract (we don't take deployer into account) to manage ALL DeNS behavior;
* 4 levels of sub-domains, 63 symbols per zone (lowercase letters and numbers) with maximum domain length of 252 symbols;
* Offline address resolving; No need to rely on factories or other contracts;
* Decentralized deployment; although the contract needs to be deployed only by another contract (deployment by external message forcefully inserts deployer keys and alters the final address) we provide you with a special deployment contract, which can be then selfdestructed (and remaining TONs withdrawn);
* No auctions; auctions allow rich people monitor new requests and buy all good-looking domains, a poor person who came with a good idea first won't be able to benefit from it;
* Previous item leads us to the domain acquisition procedure: first come - first serve;
* Transfer of ownership: at any time you can give yur domain to any other person (address or public key);
* Custom subdomain registration policy; domain owner can setup the rules for sub-domain registration (when his domain is a parent domain), which include:
    * Free and instant activation;
    * Manual approval by parent domain;
    * Automatic approval after certain amount of TONs was transfered to a parent domain (tunable parameter);
    * Only the owner of parent domain can create sub-domains;
    * Sub-domain registration can be completely closed;
* Ownership period is 90 days with free prolongation (you pay only for gas); if you forget about your domain and it expires, domain becomes free and registration rules now apply;
* Expired domains can be claimed by anyone who is lucky enough, first come - first serve;
 
## Known limitations

* DeBots are currently not supported; If there's a need to type information to DeBot instead of running a script locally (or using a fancy web-site), it will be added in the future;
* Current domain registration is 2-step registration, you deploy the DnsDeployer and then it deploys DnsRecord; SDK already allows deploying with "ZERO Public Key" override (https://github.com/tonlabs/TON-SDK/blob/master/docs/mod_abi.md#DeploySet), however TONOS-CLI still lacks this function. When TONOS-CLI starts supporting that, you won't need DnsDeployer anymore;

## How is it different?

If you read "Key DeNS features" you might think "what the hell is that and how is it even close to DeNS contest proposal?".
This submission didn't go according to a plan; this submission is a custom vision of Decentralized Name Service (DeNS), how it can be made and (maybe) how it should be made.
Traditional DNS registration procedure, as well as selling/transferring and prolongating domains feels more fair, more open and easier to understand. Blockchain technologies are modern and fast, that's why we think that expiration period of 90 days also looks fair. And again, no one takes your domain from you while you are prolongating it. If you stop taking care of your domain, it will go to the person that will, that also feels fair.

In traditional DNS registration system all free domains are equal in value until purchased. Auction-based purchase not only moves "buy date" somewhere to the future, but also allows sharks of business and sharks of thick wallets to bet more on most domains (you can even set a very high bet, because you will need to pay second biggest price). Average Joe can spend months trying to register a domain, that experience is frustrating and not healthy.

This DeNS implementation has more linear structure than tree structure: you don't need to rely on root domains to calculate any address, because calculation rules are the same for all domains.

## Usage

WARNING: repository contains key files only for showing example usage, use them only locally (i.e. TON OS SE) and only for testing, because thay are not SECURE!

Resolve an address org/freeton:
```
cd tests
./get_domain_address.sh org freeton
```

Deploy address:
```
cd tests
./get_deployer_address.sh org freeton
# put some TONs to the deployer address
./do_deploy.sh org freeton
```

**Check getters:**
```
cd tests
./dnsRecordGetter.sh _ownerPubKey org freeton
./dnsRecordGetter.sh _ownerAddress org freeton
./dnsRecordGetter.sh _regType org freeton
./dnsRecordGetter.sh _dnsName org freeton
./dnsRecordGetter.sh _endpointAddress org freeton
./dnsRecordGetter.sh _expirationDate org freeton
./dnsRecordGetter.sh _lastRegResult org freeton
./dnsRecordGetter.sh _subdomainRegPrice org freeton
```

If _lastRegResult != 2 (APPROVED), you need to take action to fix that.
See **IDnsRecord.sol:22** for details.

**Send sub-domain registration request**
```
DNS_ADDRESS=$(./get_domain_address.sh org freeton)
tonos-cli call $DNS_ADDRESS sendRegistrationRequest '{"tonsToInclude":"0"}' --sign keys1.json --abi ../contracts/DnsRecord.abi.json
```

**Change endpoint address:**
```
DNS_ADDRESS=$(./get_domain_address.sh org freeton)
tonos-cli call $DNS_ADDRESS changeEndpointAddress '{"newAddress":"0:0000000000000000000000000000000000000000000000000000000000000001"}' --sign keys1.json --abi ../contracts/DnsRecord.abi.json
```

**Change registration type:**
```
DNS_ADDRESS=$(./get_domain_address.sh org freeton)
tonos-cli call $DNS_ADDRESS setRegistrationType '{"newType":"1"}' --sign keys1.json --abi ../contracts/DnsRecord.abi.json
```

**Give DnsRecord to another person:**
```
DNS_ADDRESS=$(./get_domain_address.sh org freeton)
tonos-cli call $DNS_ADDRESS changeOwnership '{"newOwnerAddress":"0:0000000000000000000000000000000000000000000000000000000000000001", "newOwnerPubKey": "0x0000000000000000000000000000000000000000000000000000000000000000"}' --sign keys1.json --abi ../contracts/DnsRecord.abi.json
```

## Usage

Now, when you understand how DnsRecord functions are called, let's see a typical use-cases. For reading simplicity and space preservance only function()/_getter names will be written.

### Registering a top-level domain
1. Deploy a top-level domain;
2. Check registration status: ***_lastRegResult***;
3. Change endpoint address if needed: ***changeEndpointAddress()***;
4. Change registration type if needed: ***setRegistrationType()***;
5. Set subdomain registration price if needed: ***setSubdomainRegPrice()***;
6. Don't forget to prolongate your domain every 90 days, it's free (you pay only for gas): ***prolongate()***;
7. If your DnsRecord is popular and people are registering subdomains, you will want to withdraw some of the money: ***withdrawBalance()***;

### Registering a 2+level sub-domain
1. Deploy a sub-domain;
2. Take it's parent address and check registration type: ***_regType***; You have 10 days to complete the registration, otherwise DnsRecord will expire;
3. Do what you need to meet registration requirements and then try to register: ***sendRegistrationRequest()***;
4. If you are lucky, your ***_lastRegResult*** will be 2 (APPROVED);
5. Do items 2-7 from "Registering a top-level domain" list, it's basically the same;

### Claiming an expired DnsRecord
1. Check ***isExpired()*** of the desired DnsRecord  every now and then;
2. If you get "true" as a result, claim it! ***claimExpired()***;
3. After you claim it, you will have 10 days to complete the registration, otherwise DnsRecord will expire: ***sendRegistrationRequest()***; NOTE: if you are claiming root DnsRecord, it is APPROVED right away;
4. Do items 3-5 from "Registering a 2+level sub-domain" list, it's basically the same;
