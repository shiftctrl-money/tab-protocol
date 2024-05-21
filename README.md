# Tab Protocol
[ShiftCTRL](https://shiftctrl.money) is a decentralised stablecoin protocol anchored to Bitcoin. 

It allows users to mint stablecoins termed as Tabs, that are pegged to any of the 156 national currencies globally, by depositing reserves in the form of Bitcoin.

## Getting Started
1. Visit [ShiftCTRL homepage](https://shiftctrl.money) for news and information.
2. Download and read ShiftCTRL Whitepaper to understand key concepts.
3. Stay conneced with ShiftCTRL team on Twitter X and Discord.

### Prerequisites
1. Foundry
2. Node.js and npm
3. Solidity compiler ``` npm install -g solc@0.8.25 ```

### Installation
1. Install [Foundry](https://book.getfoundry.sh/getting-started/installation) and [NodeJS v16.20+](https://nodejs.org/)
2. Git clone project into your local directory.
3. Access to tab-protocol directory in your local system, run
```
npm install
forge install
forge test -vvv
```

## Current Development Stage
The project is currently being tested and optimized in [Arbitrum Sepolia testnet](https://sepolia.arbiscan.io).

Please refer to deployed smart contract addresses below:

| Contract Name                             | Deployed Address (Arbitrum Sepolia)                                                                                        |
|-------------------------------------------|----------------------------------------------------------------------------------------------------------------------------|
|CTRL Proxy Admin							|[0xf0ab89867c3053f91ebeD2b0dBe44B47BE2A0C13](https://sepolia.arbiscan.io/address/0xf0ab89867c3053f91ebed2b0dbe44b47be2a0c13)|
|CTRL										|[0xa2e9A36e4535E1c832A6c54aEA4b9954889342d3](https://sepolia.arbiscan.io/address/0xa2e9A36e4535E1c832A6c54aEA4b9954889342d3)|
|TabProxyAdmin								|[0xE546f1d0671D79319C71edC1B42089f913bc9971](https://sepolia.arbiscan.io/address/0xE546f1d0671D79319C71edC1B42089f913bc9971)|
|GovernanceTimelockController				|[0x7A4de1a4E1fd7159A810CDe7bE23C32458f7Bb46](https://sepolia.arbiscan.io/address/0x7A4de1a4E1fd7159A810CDe7bE23C32458f7Bb46)|
|GovernanceEmergencyTimelockController		|[0xC9D1EB6Ee4877D5De9b70B29dDd37A3Cf9A2175F](https://sepolia.arbiscan.io/address/0xC9D1EB6Ee4877D5De9b70B29dDd37A3Cf9A2175F)|
|ShiftCtrlGovernor							|[0xf6dD022b6404454fe75Bc0276A8E98DEF9D0Fb03](https://sepolia.arbiscan.io/address/0xf6dD022b6404454fe75Bc0276A8E98DEF9D0Fb03)|
|ShiftCtrlEmergencyGovernor					|[0xF9C8F1ECc0e701204616033f1d52Ff30B83009bB](https://sepolia.arbiscan.io/address/0xF9C8F1ECc0e701204616033f1d52Ff30B83009bB)|
|cBTC Proxy Admin							|[0x6E7fEcDb7c833EA10DC47B34dD15b1e1EdFA8449](https://sepolia.arbiscan.io/address/0x6E7fEcDb7c833EA10DC47B34dD15b1e1EdFA8449)|
|cBTC										|[0x538a7C3b36315554DDa6B1f8321c2e50fd95a271](https://sepolia.arbiscan.io/address/0x538a7C3b36315554DDa6B1f8321c2e50fd95a271)|
|GovernanceAction							|[0x7375C23a3815455D673c7366C2102e3685537B20](https://sepolia.arbiscan.io/address/0x7375C23a3815455D673c7366C2102e3685537B20)|
|VaultManager								|[0x4aEAe1e78fD0b7B329e5Ea808F124ca05Ca3BA00](https://sepolia.arbiscan.io/address/0x4aEAe1e78fD0b7B329e5Ea808F124ca05Ca3BA00)|
|TabRegistry								|[0x5B2949601CDD3721FF11bF55419F427c9C118e2c](https://sepolia.arbiscan.io/address/0x5B2949601CDD3721FF11bF55419F427c9C118e2c)|
|TabFactory									|[0x99eff83A66284459946Ff36E4c8eAa92f07d6782](https://sepolia.arbiscan.io/address/0x99eff83A66284459946Ff36E4c8eAa92f07d6782)|
|AuctionManager								|[0x7f45645523112EF72343083EB6C228088367CA74](https://sepolia.arbiscan.io/address/0x7f45645523112EF72343083EB6C228088367CA74)|
|Config										|[0x1a13d6a511A9551eC1A493C26362836e80aC4d65](https://sepolia.arbiscan.io/address/0x1a13d6a511A9551eC1A493C26362836e80aC4d65)|
|ReserveRegistry							|[0x666A895b1fcda4272A29d67c40b91a15e469F442](https://sepolia.arbiscan.io/address/0x666A895b1fcda4272A29d67c40b91a15e469F442)|
|ReserveSafe								|[0xdBcc591BaD48CA1Ab7D359C5A661C3a2150A4a08](https://sepolia.arbiscan.io/address/0xdBcc591BaD48CA1Ab7D359C5A661C3a2150A4a08)|
|PriceOracleManager							|[0x6C7deFcCf6c3bfF17BE5B241a29fA691f0E46509](https://sepolia.arbiscan.io/address/0x6C7deFcCf6c3bfF17BE5B241a29fA691f0E46509)|
|PriceOracle								|[0x2fd5AF90C453B931179B2aDDF901e2E649fE6623](https://sepolia.arbiscan.io/address/0x2fd5AF90C453B931179B2aDDF901e2E649fE6623)|
|VaultKeeper								|[0xae7a2C1eB2F7d9AFEEDCF1c850D97659087F38Ff](https://sepolia.arbiscan.io/address/0xae7a2C1eB2F7d9AFEEDCF1c850D97659087F38Ff)|
|ProtocolVault 								|[0x67E332459A81F3d64142829541b6fec608356B63](https://sepolia.arbiscan.io/address/0x67E332459A81F3d64142829541b6fec608356B63)|


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