# Tab Protocol
[ShiftCTRL](https://shiftctrl.money) is a decentralised stablecoin protocol anchored to Bitcoin. 

It allows users to mint stablecoins termed as Tabs, that are pegged to any of the 155 national currencies globally, by depositing reserves in the form of Bitcoin.

## Getting Started
1. Visit [ShiftCTRL homepage](https://shiftctrl.money) for news and information.
2. Download and read ShiftCTRL Whitepaper to understand key concepts.
3. Stay conneced with ShiftCTRL team on Twitter X and Discord.

### Prerequisites
1. Foundry
2. Node.js and npm
3. Solidity compiler ``` npm install -g solc@0.8.28 ```

### Installation
1. Install [Foundry](https://book.getfoundry.sh/getting-started/installation) and [NodeJS v16.20+](https://nodejs.org/)
2. Git clone project into your local directory.
3. Access to tab-protocol directory in your local system, run
```
npm install
git submodule update
forge test -vvv
```

## Current Development Stage
The project is currently being tested in [Base Sepolia testnet](https://sepolia.basescan.org).

You may visit [Qwerty](https://qwerty.shiftctrl.money) to join testing.

CBBTC token is used as protocol reserve, visit [Faucet](https://qwerty.shiftctrl.money/faucet) to request test token.

Check on [Tab Contract Address](https://github.com/shiftctrl-money/tab-protocol/blob/92d3eb29e8b9c2d8a0d275c63efb56f4ff0c3de8/contracts/token/Tabs.md) to add minted Tabs into your wallet.

Please refer to deployed smart contract addresses below:

| Contract Name                             | Deployed Address (Base Sepolia)                                                                                        |
|-------------------------------------------|----------------------------------------------------------------------------------------------------------------------------|
|TabProxyAdmin  							|[0x2c112a83E7859c7e513C94ee95B55707c87f6004](https://sepolia.basescan.org/address/0x2c112a83E7859c7e513C94ee95B55707c87f6004)|
|CTRL										|[0x7F53Fb785Feee996117205e2b81e4D77755701Fe](https://sepolia.basescan.org/address/0x7F53Fb785Feee996117205e2b81e4D77755701Fe)|
|GovernanceTimelockController				|[0x4e41d11Cb9540891a55B9744a59025E5382DDeCF](https://sepolia.basescan.org/address/0x4e41d11Cb9540891a55B9744a59025E5382DDeCF)|
|GovernanceEmergencyTimelockController		|[0xE5A01AD9d0065e66553B3bF9C3E12F0b6aC20201](https://sepolia.basescan.org/address/0xE5A01AD9d0065e66553B3bF9C3E12F0b6aC20201)|
|ShiftCtrlGovernor							|[0x6EdeC03274302038C3A3E8C3853E100f6A67D10f](https://sepolia.basescan.org/address/0x6EdeC03274302038C3A3E8C3853E100f6A67D10f)|
|ShiftCtrlEmergencyGovernor					|[0x82d558fD3a71fB4E1256424E8be724Cb5Ca744A5](https://sepolia.basescan.org/address/0x82d558fD3a71fB4E1256424E8be724Cb5Ca744A5)|
|cbBTC (simulated for testnet)				|[0xfDd7b819ca8422e2031abA3A46cE2Ee2386E3c13](https://sepolia.basescan.org/address/0xfDd7b819ca8422e2031abA3A46cE2Ee2386E3c13)|
|GovernanceAction							|[0xfE8F568092ebBaE143af77952e2AE222d6E56896](https://sepolia.basescan.org/address/0xfE8F568092ebBaE143af77952e2AE222d6E56896)|
|VaultManager								|[0x11276132F98756673d66DBfb424d0ae0510d9219](https://sepolia.basescan.org/address/0x11276132F98756673d66DBfb424d0ae0510d9219)|
|VaultUtils                                 |[0x8786dA72C762e4A83286cD91b0CBC9a7C8E5531B](https://sepolia.basescan.org/address/0x8786dA72C762e4A83286cD91b0CBC9a7C8E5531B)|
|TabRegistry								|[0x33B54050d72c8Ffeb6c0d7E0857c7C012643DeA0](https://sepolia.basescan.org/address/0x33B54050d72c8Ffeb6c0d7E0857c7C012643DeA0)|
|TabFactory									|[0x9F440e98dD11a44AeDC8CA88bb7cA3756fdfFED1](https://sepolia.basescan.org/address/0x9F440e98dD11a44AeDC8CA88bb7cA3756fdfFED1)|
|AuctionManager								|[0xA4C2b64Bd05BF29c297C06D5bd1DaC3E99F57558](https://sepolia.basescan.org/address/0xA4C2b64Bd05BF29c297C06D5bd1DaC3E99F57558)|
|Config										|[0x61f2f994d35fDc75990Fe273e34913a3AcC928E6](https://sepolia.basescan.org/address/0x61f2f994d35fDc75990Fe273e34913a3AcC928E6)|
|ReserveRegistry							|[0x5824F087B9AE3327e0Ee9cc9DB04E2Cc08ec1BA3](https://sepolia.basescan.org/address/0x5824F087B9AE3327e0Ee9cc9DB04E2Cc08ec1BA3)|
|ReserveSafe    							|[0xF308055b4b8Ea0ccec1699cab524185967c28ea0](https://sepolia.basescan.org/address/0xF308055b4b8Ea0ccec1699cab524185967c28ea0)|
|PriceOracleManager							|[0x192Ee2bAD42B9e4C903975fE5615888e39be7A6a](https://sepolia.basescan.org/address/0x192Ee2bAD42B9e4C903975fE5615888e39be7A6a)|
|PriceOracle								|[0xa6188Fcd9f90F76c692D139099D9909B78fb632c](https://sepolia.basescan.org/address/0xa6188Fcd9f90F76c692D139099D9909B78fb632c)|
|VaultKeeper								|[0xd9AF87C4D2Ff3f250f6B3a66C9313e37d912117b](https://sepolia.basescan.org/address/0xd9AF87C4D2Ff3f250f6B3a66C9313e37d912117b)|
|ProtocolVault 								|[0xD5D2DA37819FCa1514570499B6eA59F98A57f2aF](https://sepolia.basescan.org/address/0xD5D2DA37819FCa1514570499B6eA59F98A57f2aF)|

## Contributing

Any contributions you make are **greatly appreciated**.

If you have a suggestion that would make this better, please fork the repo and create a pull request. 
You can also simply open an issue with the tag "enhancement".
Don't forget to give the project a star! Thanks again!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License
Distributed under the MIT License. See `LICENSE` file for more information.

## Contact
Project Link: [https://shiftctrl.money](https://shiftctrl.money) - contact@shiftctrl.money

Twitter [@shiftCTRL_money](https://twitter.com/shiftCTRL_money) 

Discord [shiftctrl_money](https://discord.gg/7w6JhTNt9K)