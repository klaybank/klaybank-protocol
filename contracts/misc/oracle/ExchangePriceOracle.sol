pragma solidity 0.6.12;

import "../../dependencies/openzeppelin/contracts/Ownable.sol";
import "../../interfaces/IPriceOracleGetter.sol";

contract ExchangePriceOracle is IPriceOracleGetter, Ownable {
    mapping(address => uint256) prices;

    mapping(address => uint256) assetLastUpdatedTimestamp;

    address usdtAddress;
    uint256 klayPriceUsd;
    uint256 timestampThreshold;

    event AssetPriceUpdated(address _asset, uint256 _price, uint256 timestamp);
    event KlayPriceUpdated(uint256 _price, uint256 timestamp);
    constructor (uint initialTimestampThreshold) public {
        timestampThreshold = initialTimestampThreshold;
    }

    function setUsdtAddress(address _usdtAddress) onlyOwner public {
        usdtAddress = _usdtAddress;
    }

    function setTimestampThreshold(uint _threshold) onlyOwner public {
        timestampThreshold = _threshold;
    }

    function getAssetPrice(address _asset) public view override returns (uint256) {
        if (assetLastUpdatedTimestamp[_asset] + timestampThreshold < block.timestamp) {
            return 0;
        }
        return prices[_asset];
    }

    function setAssetPrice(address _asset, uint256 _price) onlyOwner external {
        prices[_asset] = _price;
        assetLastUpdatedTimestamp[_asset] = block.timestamp;
        emit AssetPriceUpdated(_asset, _price, block.timestamp);
    }

    function getKlayUsdPrice() public view returns (uint256) {
        return klayPriceUsd;
    }

    function setKlayUsdPrice(uint256 _price) onlyOwner external {
        klayPriceUsd = _price;
        assetLastUpdatedTimestamp[address(0x0)] = block.timestamp;
        emit KlayPriceUpdated(_price, block.timestamp);
    }

    function getAssetPriceInUsd(address _asset) external view returns (uint256){
        uint256 assetPerKlay = this.getAssetPrice(_asset) * 1e6;
        uint256 usdtPerKlay = this.getAssetPrice(usdtAddress);
        return assetPerKlay / usdtPerKlay;
    }
}
