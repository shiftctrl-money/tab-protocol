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

## Deployments
The project is deployed to [BASE mainnet](https://www.base.org) (currently in Alpha phase). Please visit [Qwerty](https://qwerty.shiftctrl.money) to open the application.
The protocol accepts [$cbBTC](https://basescan.org/address/0xcbb7c0000ab88b473b1f5afd9ef808440eed33bf) as reserve token.
For governance, refer [$CTRL](https://basescan.org/address/0x505568c65fF95E5e97Ca97B476BEb0db64F91499) token.

## Mainnet Smart Contracts:

| Contract Name                               | Deployed Address (Base Mainnet)                                                                                     |
|---------------------------------------------|---------------------------------------------------------------------------------------------------------------------|
|TabProxyAdmin  							  |[0x65FB1EF0f9C15b2653421D9008fd7E55889890E2](https://basescan.org/address/0x65FB1EF0f9C15b2653421D9008fd7E55889890E2)|
|CTRL								  	   	  |[0x505568c65fF95E5e97Ca97B476BEb0db64F91499](https://basescan.org/address/0x505568c65fF95E5e97Ca97B476BEb0db64F91499)|
|GovernanceTimelockController		    	  |[0x75977C03b7AFc9B0E645A6402B2b46E438F146D5](https://basescan.org/address/0x75977C03b7AFc9B0E645A6402B2b46E438F146D5)|
|GovernanceEmergencyTimelockController		  |[0x4bedAa52B64A4b8aff01a5354516c2897ecEf58B](https://basescan.org/address/0x4bedAa52B64A4b8aff01a5354516c2897ecEf58B)|
|ShiftCtrlGovernor							  |[0x747E429c1ceb8b0FB576650BEd6623785eAb0348](https://basescan.org/address/0x747E429c1ceb8b0FB576650BEd6623785eAb0348)|
|ShiftCtrlEmergencyGovernor					  |[0x95205Ed4F55a012DCfd1497aEecc3C3A66496b22](https://basescan.org/address/0x95205Ed4F55a012DCfd1497aEecc3C3A66496b22)|
|[cbBTC](https://www.coinbase.com/en-gb/cbbtc)|[0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf](https://basescan.org/address/0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf)|
|GovernanceAction							  |[0xEBf09013763412Eb1108257fde050545F780D09c](https://basescan.org/address/0xEBf09013763412Eb1108257fde050545F780D09c)|
|VaultManager								  |[0x11138452B689fd55d5Ad3991A6166dbBb6C2A774](https://basescan.org/address/0x11138452B689fd55d5Ad3991A6166dbBb6C2A774)|
|VaultUtils                                   |[0x4034a758F7CFB316f5923B7a2568D8ff21ea998a](https://basescan.org/address/0x4034a758F7CFB316f5923B7a2568D8ff21ea998a)|
|TabRegistry								  |[0x01D988944c3Bb067f56e600619345C3dB161f444](https://basescan.org/address/0x01D988944c3Bb067f56e600619345C3dB161f444)|
|TabFactory									  |[0x83F19d560935F5299E7DE4296e7cb7adA0417525](https://basescan.org/address/0x83F19d560935F5299E7DE4296e7cb7adA0417525)|
|AuctionManager								  |[0x731D9aD52663c2767A48303D09a668F9cE3aecc4](https://basescan.org/address/0x731D9aD52663c2767A48303D09a668F9cE3aecc4)|
|Config										  |[0xC81455d98AD16db5043c775bD1eCd2677E39e670](https://basescan.org/address/0xC81455d98AD16db5043c775bD1eCd2677E39e670)|
|ReserveRegistry							  |[0xb59B6ba5426255B669C3966261aC4b2D59A76943](https://basescan.org/address/0xb59B6ba5426255B669C3966261aC4b2D59A76943)|
|ReserveSafe    							  |[0x6cdEB78a62bD94f2c08D6AbB0f1412B0F959a9A0](https://basescan.org/address/0x6cdEB78a62bD94f2c08D6AbB0f1412B0F959a9A0)|
|PriceOracleManager							  |[0x5f6c5A786a1Aa89d3B18606f93Dc6bfA011a2fBC](https://basescan.org/address/0x5f6c5A786a1Aa89d3B18606f93Dc6bfA011a2fBC)|
|PriceOracle								  |[0x8c3Fd83a9dFEC3D5e389aea60cA980A2e72A9A5A](https://basescan.org/address/0x8c3Fd83a9dFEC3D5e389aea60cA980A2e72A9A5A)|
|VaultKeeper								  |[0xBbFD14d040b7E3b3cC3eef52DCB1E84Cb3E397C5](https://basescan.org/address/0xBbFD14d040b7E3b3cC3eef52DCB1E84Cb3E397C5)|
|ProtocolVault 								  |N/A                                                                                                                  |

## Testnet

Please visit [Test Application](https://test.shiftctrl.money) deployed to [Base Sepolia Testnet](https://sepolia.basescan.org).
Use [Faucet](https://test.shiftctrl.money/faucet) to get test tokens ($cbBTC and $CTRL).

## Testnet Smart Contracts:

| Contract Name                             | Deployed Address (Base Sepolia)                                                                                        |
|-------------------------------------------|----------------------------------------------------------------------------------------------------------------------------|
|TabProxyAdmin  							|[0xF44013D4BE0F452938B0b805Bc5Bf0D3Fbd4102c](https://sepolia.basescan.org/address/0xF44013D4BE0F452938B0b805Bc5Bf0D3Fbd4102c)|
|CTRL										|[0x193410b8cdeD8F4D63E43D0f2AeD99bd862ed1Bc](https://sepolia.basescan.org/address/0x193410b8cdeD8F4D63E43D0f2AeD99bd862ed1Bc)|
|GovernanceTimelockController				|[0x783bDAF73E8F40672421204d6FF3f448767d72c6](https://sepolia.basescan.org/address/0x783bDAF73E8F40672421204d6FF3f448767d72c6)|
|GovernanceEmergencyTimelockController		|[0x997275213b66AEAAb4042dF9457F2913969368f2](https://sepolia.basescan.org/address/0x997275213b66AEAAb4042dF9457F2913969368f2)|
|ShiftCtrlGovernor							|[0x89E7068cf18F22765D1F2902d1BaB8C839B8d013](https://sepolia.basescan.org/address/0x89E7068cf18F22765D1F2902d1BaB8C839B8d013)|
|ShiftCtrlEmergencyGovernor					|[0xcb41b90E53C227241cdB018e87797afcE158d061](https://sepolia.basescan.org/address/0xcb41b90E53C227241cdB018e87797afcE158d061)|
|cbBTC (simulated for testnet)				|[0x7eC62ECbE14B6E3A8B70942dFDf302B4dd9d6a51](https://sepolia.basescan.org/address/0x7eC62ECbE14B6E3A8B70942dFDf302B4dd9d6a51)|
|GovernanceAction							|[0xE1a5CC4599DA4bd2D25F57442222647Fe1B69Dda](https://sepolia.basescan.org/address/0xE1a5CC4599DA4bd2D25F57442222647Fe1B69Dda)|
|VaultManager								|[0xeAf6aB024D4a7192322090Fea1C402a5555cD107](https://sepolia.basescan.org/address/0xeAf6aB024D4a7192322090Fea1C402a5555cD107)|
|VaultUtils                                 |[0x99843f8306AecdDC8EE6d47F1A144836D332a5B4](https://sepolia.basescan.org/address/0x99843f8306AecdDC8EE6d47F1A144836D332a5B4)|
|TabRegistry								|[0x9b2F93f5be029Fbb4Cb51491951943f7368b2f1C](https://sepolia.basescan.org/address/0x9b2F93f5be029Fbb4Cb51491951943f7368b2f1C)|
|TabFactory									|[0x83F19d560935F5299E7DE4296e7cb7adA0417525](https://sepolia.basescan.org/address/0x83F19d560935F5299E7DE4296e7cb7adA0417525)|
|AuctionManager								|[0xB93cb66DFaa0cDA61D83BF9f39A076EA2fa2827B](https://sepolia.basescan.org/address/0xB93cb66DFaa0cDA61D83BF9f39A076EA2fa2827B)|
|Config										|[0x25B9982A32106EeB2Aa052319011De58A7d33457](https://sepolia.basescan.org/address/0x25B9982A32106EeB2Aa052319011De58A7d33457)|
|ReserveRegistry							|[0xDA8A64cDFaeb08b3f28b072b0d4aC371953F5B6E](https://sepolia.basescan.org/address/0xDA8A64cDFaeb08b3f28b072b0d4aC371953F5B6E)|
|ReserveSafe    							|[0xE8a28176Bed3a53CBF2Bc65B597811909F1A1389](https://sepolia.basescan.org/address/0xE8a28176Bed3a53CBF2Bc65B597811909F1A1389)|
|PriceOracleManager							|[0xBdFd9503f62A23092504eD072158092B6B3342ac](https://sepolia.basescan.org/address/0xBdFd9503f62A23092504eD072158092B6B3342ac)|
|PriceOracle								|[0x7a65f5f7b2ba2F15468688c8e98835A3f9be2520](https://sepolia.basescan.org/address/0x7a65f5f7b2ba2F15468688c8e98835A3f9be2520)|
|VaultKeeper								|[0x303818F385f1675BBB07dDE155987f6b7041753c](https://sepolia.basescan.org/address/0x303818F385f1675BBB07dDE155987f6b7041753c)|
|ProtocolVault 								|[0xBC6bef5A3a1211B033322F3730e8DFf2f81AcA84](https://sepolia.basescan.org/address/0xBC6bef5A3a1211B033322F3730e8DFf2f81AcA84)|

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