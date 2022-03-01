pragma solidity 0.6.12;

import "../../dependencies/openzeppelin/contracts/Ownable.sol";
import "../../interfaces/IPriceOracleGetter.sol";

contract StaticPriceOracle is IPriceOracleGetter {
    mapping(address => uint256) prices;
    uint256 klayPriceUsd;

    function getAssetPrice(address _asset) external view override returns (uint256) {
        return prices[_asset];
    }

    function setAssetPrice(address _asset, uint256 _price) external {
        prices[_asset] = _price;
    }

    function setAssetPrices(address[] memory _asset, uint256[] memory _price) external {
        require(_asset.length == _price.length, "i");
        for (uint i = 0; i < _asset.length; i++) {
            prices[_asset[i]] = _price[i];
        }
    }

    function getKlayUsdPrice() external view returns (uint256) {
        return klayPriceUsd;
    }

    function setKlayUsdPrice(uint256 _price) external {
        klayPriceUsd = _price;
    }

    function getAssetPriceInUsd(address asset) external view returns (uint256){
        uint assetPerKlay = this.getAssetPrice(asset);
        uint klayPerUsd = this.getKlayUsdPrice();
        return assetPerKlay / klayPerUsd;
    }
}
