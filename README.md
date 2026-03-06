# Tab Protocol
[ShiftCTRL](https://shiftctrl.money) is a decentralised stablecoin protocol anchored to Bitcoin. 

It allows users to mint stablecoins termed as Tabs, that are pegged to any of the 155 national currencies globally, by depositing reserves in the form of Bitcoin.
The latest version enabled [Universal Tab](https://github.com/shiftctrl-money/tab-protocol/issues/17) enhancements.

## Getting Started
1. Visit [ShiftCTRL homepage](https://shiftctrl.money) for news and information.
2. Download and read ShiftCTRL Whitepaper to understand key concepts.
3. Stay conneced with ShiftCTRL team on [X](https://x.com/shiftCTRL_money) and [Discord](https://discord.gg/7w6JhTNt9K).

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
The project is deployed to [ZetaChain Mainnet beta](https://www.zetachain.com) for core contracts, and currently 3 supported chains (Ethereum, Arbitrum, and Base) to support Universal Tab features.
Please visit [Qwerty](https://qwerty.shiftctrl.money) to open the application.

## Smart Contracts

| Contract Name                             | Deployed Address (ZetaChain Testnet - Chain Id 7001)                                                                        |
|-------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------|
|CTRL										|[0xfD0c816B8e028DD5F0F04f9bF58e785325D83D2f](https://testnet.zetascan.org/address/0xfD0c816B8e028DD5F0F04f9bF58e785325D83D2f)|
|VaultManager								|[0x0046fFc38C0Cc854A56b6daeF66946F04d61639B](https://testnet.zetascan.org/address/0x0046fFc38C0Cc854A56b6daeF66946F04d61639B)|
|TabRegister								|[0xFBE4da9950eddA7F43be8bD49B1F9966B786C542](https://testnet.zetascan.org/address/0xFBE4da9950eddA7F43be8bD49B1F9966B786C542)|
|TabFactory									|[0x02E89328C7B07a1eFE410eaa604A9b5A3C2556de](https://testnet.zetascan.org/address/0x02E89328C7B07a1eFE410eaa604A9b5A3C2556de)|
|ReserveRegistry							|[0x3cD93D91fc5Df61A10c86145d27574878136CDFe](https://testnet.zetascan.org/address/0x3cD93D91fc5Df61A10c86145d27574878136CDFe)|
|cbBTC (simulated for testnet)				|[0x215Af41ce2c372B70aA710ca4eE38624FA9984B0](https://testnet.zetascan.org/address/0x215Af41ce2c372B70aA710ca4eE38624FA9984B0)|
|ReserveSafe								|[0x26200d45B70cB5901b46371E1a0370277530eCa6](https://testnet.zetascan.org/address/0x26200d45B70cB5901b46371E1a0370277530eCa6)|
|AuctionManager								|[0x13A0E137Bae4C88A243a48E2d10c1F7227f7f22C](https://testnet.zetascan.org/address/0x13A0E137Bae4C88A243a48E2d10c1F7227f7f22C)|
|Config                            	        |[0x293E347F2e0651a1ddbec114E9bD0Df9Ef223195](https://testnet.zetascan.org/address/0x293E347F2e0651a1ddbec114E9bD0Df9Ef223195)|
|VaultUtils									|[0xA4b7eB0F7180f153cD2D6d9A0c09595e01F120aD](https://testnet.zetascan.org/address/0xA4b7eB0F7180f153cD2D6d9A0c09595e01F120aD)|
|PriceOracleManager							|[0xB0f26c400f1a8897b44B3c13C916d581aDA230F0](https://testnet.zetascan.org/address/0xB0f26c400f1a8897b44B3c13C916d581aDA230F0)|
|PriceOracle								|[0x4D8A74539F8Ab69bb20D0aa51b2b587040861286](https://testnet.zetascan.org/address/0x4D8A74539F8Ab69bb20D0aa51b2b587040861286)|
|VaultKeeper								|[0x9E5d2D8E86067B76B0eC8599Cd17aD9C77775ee3](https://testnet.zetascan.org/address/0x9E5d2D8E86067B76B0eC8599Cd17aD9C77775ee3)|
|ProtocolVault								|[0x2012C92c17E3d6cD7b1BbD0C7438D3d767301eF2](https://testnet.zetascan.org/address/0x2012C92c17E3d6cD7b1BbD0C7438D3d767301eF2)|
|ZUniCreateVault   							|[0x79842c65b050ce9e45835261BD50a707Dc0FB25C](https://testnet.zetascan.org/address/0x79842c65b050ce9e45835261BD50a707Dc0FB25C)|
|ZUniDepositReserve							|[0x796805d483e6592Ef9977CDA7DD8A8Bc02fD0411](https://testnet.zetascan.org/address/0x796805d483e6592Ef9977CDA7DD8A8Bc02fD0411)|
|ZUniWithdrawReserve						|[0xe295A65Aa0B41D3BC6c517a61Cbeaf89f647E9c9](https://testnet.zetascan.org/address/0xe295A65Aa0B41D3BC6c517a61Cbeaf89f647E9c9)|
|ZUniWithdrawTab							|[0x5E0B3463ABA1e685AC7c8Bd5B04dbf6db75B5B04](https://testnet.zetascan.org/address/0x5E0B3463ABA1e685AC7c8Bd5B04dbf6db75B5B04)|
|ZUniProtocolVaultBuyTab 					|[0xb2637Ac71aF04f7BF783dfB6dc3A2a47fa81f826](https://testnet.zetascan.org/address/0xb2637Ac71aF04f7BF783dfB6dc3A2a47fa81f826)|
|ZUniGovernance  							|[0x5d412eF840a56f252060b11192D2441EcfD9137A](https://testnet.zetascan.com/address/0x5d412eF840a56f252060b11192D2441EcfD9137A)|
|ZUniTab									|[0x4d8107756C322134cCDfB33579BC3e3921040E29](https://testnet.zetascan.org/address/0x4d8107756C322134cCDfB33579BC3e3921040E29)|

| Contract Name                             | Deployed Address (Base Sepolia Testnet - Chain Id 84532)                                                                    |
|-------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------|
|CTRL										|[0xfD0c816B8e028DD5F0F04f9bF58e785325D83D2f](https://sepolia.basescan.org/address/0xfD0c816B8e028DD5F0F04f9bF58e785325D83D2f)|
|GovernanceTimelockController				|[0xAAA63097503f34fe068AC55F6fe1476BA89fa9b1](https://sepolia.basescan.org/address/0xAAA63097503f34fe068AC55F6fe1476BA89fa9b1)|
|GovernanceEmergencyTimelockController		|[0xe80D7E122AAF65bF3F2D11017D773725a32c2350](https://sepolia.basescan.org/address/0xe80D7E122AAF65bF3F2D11017D773725a32c2350)|
|ShiftCtrlGovernor							|[0x276f96570973d2F0Bd3F12C95871d8aD3C2e6183](https://sepolia.basescan.org/address/0x276f96570973d2F0Bd3F12C95871d8aD3C2e6183)|
|ShiftCtrlEmergencyGovernor					|[0xb52263C57B9cb73d30AB05355ec8b54E303449Af](https://sepolia.basescan.org/address/0xb52263C57B9cb73d30AB05355ec8b54E303449Af)|
|UniGovernance								|[0xfD08512a1EDAcE7EDab28429a05cAe108501cc56](https://sepolia.basescan.org/address/0xfD08512a1EDAcE7EDab28429a05cAe108501cc56)|
|UniTab										|[0xEb8173CDc1fbBF190DF03DF10D066e0703c9e08c](https://sepolia.basescan.org/address/0xEb8173CDc1fbBF190DF03DF10D066e0703c9e08c)|
|TabFactory									|[0x02E89328C7B07a1eFE410eaa604A9b5A3C2556de](https://sepolia.basescan.org/address/0x02E89328C7B07a1eFE410eaa604A9b5A3C2556de)|
|UniCreateVault   							|[0xb4BE521b1D2e89a0f40eD10D3615b60f7413CEE8](https://sepolia.basescan.org/address/0xb4BE521b1D2e89a0f40eD10D3615b60f7413CEE8)|
|UniDepositReserve							|[0x30aC390cc81A4A7EBd42c00C87d2229b25370BA8](https://sepolia.basescan.org/address/0x30aC390cc81A4A7EBd42c00C87d2229b25370BA8)|
|UniWithdrawReserve							|[0xc437dfC119984C8d90E83436DfE90E68F1586ff8](https://sepolia.basescan.org/address/0xc437dfC119984C8d90E83436DfE90E68F1586ff8)|
|UniPaybackTab								|[0x61477fD0C27be7648bB5bE99268ecBCd51527a9C](https://sepolia.basescan.org/address/0x61477fD0C27be7648bB5bE99268ecBCd51527a9C)|
|UniWithdrawTab								|[0xD7D541788550e2b2f51C46eE299B539342feD4E3](https://sepolia.basescan.org/address/0xD7D541788550e2b2f51C46eE299B539342feD4E3)|
|UniAuctionBid								|[0x383f719Dad554bc535C31539E9F7700EA9587560](https://sepolia.basescan.org/address/0x383f719Dad554bc535C31539E9F7700EA9587560)|
|UniProtocolVaultBuyTab 					|[0x9173450d84368FE7e79B115EA8aF72BF774309C2](https://sepolia.basescan.org/address/0x9173450d84368FE7e79B115EA8aF72BF774309C2)|
|UniProtocolVaultSellTab 					|[0x4B50d2002368b209Aa05ebF8310C9ec9FFD8d4a8](https://sepolia.basescan.org/address/0x4B50d2002368b209Aa05ebF8310C9ec9FFD8d4a8)|

| Contract Name                             | Deployed Address (Arbitrum Sepolia Testnet - Chain Id 421614)                                                              |
|-------------------------------------------|----------------------------------------------------------------------------------------------------------------------------|
|UniGovernance								|[0xfD08512a1EDAcE7EDab28429a05cAe108501cc56](https://sepolia.arbiscan.io/address/0xfD08512a1EDAcE7EDab28429a05cAe108501cc56)|
|UniTab										|[0xEb8173CDc1fbBF190DF03DF10D066e0703c9e08c](https://sepolia.arbiscan.io/address/0xEb8173CDc1fbBF190DF03DF10D066e0703c9e08c)|
|TabFactory									|[0x02E89328C7B07a1eFE410eaa604A9b5A3C2556de](https://sepolia.arbiscan.io/address/0x02E89328C7B07a1eFE410eaa604A9b5A3C2556de)|
|UniCreateVault   							|[0xb4BE521b1D2e89a0f40eD10D3615b60f7413CEE8](https://sepolia.arbiscan.io/address/0xb4BE521b1D2e89a0f40eD10D3615b60f7413CEE8)|
|UniDepositReserve							|[0x30aC390cc81A4A7EBd42c00C87d2229b25370BA8](https://sepolia.arbiscan.io/address/0x30aC390cc81A4A7EBd42c00C87d2229b25370BA8)|
|UniWithdrawReserve							|[0xc437dfC119984C8d90E83436DfE90E68F1586ff8](https://sepolia.arbiscan.io/address/0xc437dfC119984C8d90E83436DfE90E68F1586ff8)|
|UniPaybackTab								|[0x61477fD0C27be7648bB5bE99268ecBCd51527a9C](https://sepolia.arbiscan.io/address/0x61477fD0C27be7648bB5bE99268ecBCd51527a9C)|
|UniWithdrawTab								|[0xD7D541788550e2b2f51C46eE299B539342feD4E3](https://sepolia.arbiscan.io/address/0xD7D541788550e2b2f51C46eE299B539342feD4E3)|
|UniAuctionBid								|[0x383f719Dad554bc535C31539E9F7700EA9587560](https://sepolia.arbiscan.io/address/0x383f719Dad554bc535C31539E9F7700EA9587560)|
|UniProtocolVaultBuyTab 					|[0x9173450d84368FE7e79B115EA8aF72BF774309C2](https://sepolia.arbiscan.io/address/0x9173450d84368FE7e79B115EA8aF72BF774309C2)|
|UniProtocolVaultSellTab 					|[0x4B50d2002368b209Aa05ebF8310C9ec9FFD8d4a8](https://sepolia.arbiscan.io/address/0x4B50d2002368b209Aa05ebF8310C9ec9FFD8d4a8)|

| Contract Name                             | Deployed Address (Ethereum Sepolia Testnet - Chain Id 11155111)                                                             |
|-------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------|
|UniGovernance								|[0xfD08512a1EDAcE7EDab28429a05cAe108501cc56](https://sepolia.etherscan.io/address/0xfD08512a1EDAcE7EDab28429a05cAe108501cc56)|
|UniTab										|[0xEb8173CDc1fbBF190DF03DF10D066e0703c9e08c](https://sepolia.etherscan.io/address/0xEb8173CDc1fbBF190DF03DF10D066e0703c9e08c)|
|TabFactory									|[0x02E89328C7B07a1eFE410eaa604A9b5A3C2556de](https://sepolia.etherscan.io/address/0x02E89328C7B07a1eFE410eaa604A9b5A3C2556de)|
|UniCreateVault   							|[0xb4BE521b1D2e89a0f40eD10D3615b60f7413CEE8](https://sepolia.etherscan.io/address/0xb4BE521b1D2e89a0f40eD10D3615b60f7413CEE8)|
|UniDepositReserve							|[0x30aC390cc81A4A7EBd42c00C87d2229b25370BA8](https://sepolia.etherscan.io/address/0x30aC390cc81A4A7EBd42c00C87d2229b25370BA8)|
|UniWithdrawReserve							|[0xc437dfC119984C8d90E83436DfE90E68F1586ff8](https://sepolia.etherscan.io/address/0xc437dfC119984C8d90E83436DfE90E68F1586ff8)|
|UniPaybackTab								|[0x61477fD0C27be7648bB5bE99268ecBCd51527a9C](https://sepolia.etherscan.io/address/0x61477fD0C27be7648bB5bE99268ecBCd51527a9C)|
|UniWithdrawTab								|[0xD7D541788550e2b2f51C46eE299B539342feD4E3](https://sepolia.etherscan.io/address/0xD7D541788550e2b2f51C46eE299B539342feD4E3)|
|UniAuctionBid								|[0x383f719Dad554bc535C31539E9F7700EA9587560](https://sepolia.etherscan.io/address/0x383f719Dad554bc535C31539E9F7700EA9587560)|
|UniProtocolVaultBuyTab 					|[0x9173450d84368FE7e79B115EA8aF72BF774309C2](https://sepolia.etherscan.io/address/0x9173450d84368FE7e79B115EA8aF72BF774309C2)|
|UniProtocolVaultSellTab 					|[0x4B50d2002368b209Aa05ebF8310C9ec9FFD8d4a8](https://sepolia.etherscan.io/address/0x4B50d2002368b209Aa05ebF8310C9ec9FFD8d4a8)|

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