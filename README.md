# FreeTON DeNS

Unfortunately, initial contest requirements are not good enough for a decentralized DeNS, because they focus on the rich to get all the good domain names.
There is no perfect solution, but we tend to believe that this one is easy and fair enough for everyone.

## Key DeNS features:

* 4 levels of sub-domains, 63 symbols per zone (lowercase letters and numbers) with maximum domain length of 252 symbols;
* Offline address resolving; No need to rely on factories or other contracts;
* Decentralized deployment; although the contract needs to be deployed only by another contract (deployment by external message forcefully inserts deployer keys and alters the final address) we provide you with a special deployment contract, which can be then selfdestructed (and remaining TONs withdrawn);
* No auctions; auctions allow rich people monitor new requests and buy all good-looking domains, a poor person who came with a good idea first won't be able to benefit from it;
* Previous item leads us to the domain acquisituon procedure: first come - first serve;
* Transfer of ownership: at any time you can give yur domain to any other person (address or public key);
* Custom subdomain registration policy; domain owner can setup the rules for sub-domain registration (when his domain is a parent domain), which include:
* Free and instant activation;
    * Manual approval by parent domain;
    * Automatic approval after certain amount of TONs was transfered to a parent domain (tunable parameter);
    * Only the owner of parent domain can create sub-domains;
    * Sub-domain registration can be completely closed;
* Ownership period is 60 days with free prolongation (you pay only for gas); if you forget about your domain and it expires, domain becomes free and registration rules now apply;
* Expired domains can be claimed by anyone who is lucky enough, first come - first serve;
 
## Usage

WARNING: repository contains key files, use them only locally (i.e. TON OS SE) and only for testing, because thay are not SECURE!

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
./do_deploy org freeton
```

Change registration type
```
DNS_ADDRESS=$(./get_domain_address.sh org freeton)
tonos-cli call $DNS_ADDRESS setRegistrationType '{"newType":"1"}' --sign keys1.json --abi ../contracts/DnsRecord.abi.json
```

Check registration status:
```
cd tests
DNS_ADDRESS=$(./get_domain_address.sh org freeton)
tonos-cli run $DNS_ADDRESS _lastRegResult {} --abi ../contracts/DnsRecord.abi.json
```
