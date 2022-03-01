pragma solidity 0.6.12;

import {Ownable} from '../../dependencies/openzeppelin/contracts/Ownable.sol';
import {IKIP7} from '../../dependencies/openzeppelin/contracts/IKIP7.sol';
import {SafeKIP7} from '../../dependencies/openzeppelin/contracts/SafeKIP7.sol';
import {IKlaybankOracle} from '../../interfaces/IKlaybankOracle.sol';

contract KlaybankOracle is IKlaybankOracle, Ownable {
  using SafeKIP7 for IKIP7;

  address public immutable WKLAY;
  address[] assetPriceOracles;

  event AssetOracleUpdated(uint indexed idx, address indexed source);

  constructor(
    address wklay,
    address[] memory _assetPriceOracles
  ) public {
    _setAssetOracles(_assetPriceOracles);
    WKLAY = wklay;
  }

  function setAssetOracles(address[] calldata oracles)
  external
  onlyOwner
  {
    _setAssetOracles(oracles);
  }

  function _setAssetOracles(address[] memory oracles) internal {
    //        require(oracles.length > 2, 'INCONSISTENT_PARAMS_LENGTH');
    delete assetPriceOracles;
    for (uint256 i = 0; i < oracles.length; i++) {
      assetPriceOracles.push(oracles[i]);
      emit AssetOracleUpdated(i, oracles[i]);
    }
  }

  function getAssetPrice(address asset) public view override returns (uint256) {
    if (asset == WKLAY) {
      return 1 ether;
    }
    for (uint i = 0; i < assetPriceOracles.length; i++) {
      IKlaybankOracle source = IKlaybankOracle(assetPriceOracles[i]);
      uint price = source.getAssetPrice(asset);
      if (price > 0) {
        return price;
      }
    }
    revert("CANNOT GET ASSET PRICE");
  }

  function getKlayUsdPrice() external view override returns (uint256){
    for (uint i = 0; i < assetPriceOracles.length; i++) {
      IKlaybankOracle source = IKlaybankOracle(assetPriceOracles[i]);
      uint price = source.getKlayUsdPrice();
      if (price > 0) {
        return price;
      }
    }
    revert("CANNOT GET ASSET PRICE");
  }

  function getAssetPriceInUsd(address asset) external view override returns (uint256){
    for (uint i = 0; i < assetPriceOracles.length; i++) {
      IKlaybankOracle source = IKlaybankOracle(assetPriceOracles[i]);
      uint price = source.getAssetPriceInUsd(asset);
      if (price > 0) {
        return price;
      }
    }
    revert("CANNOT GET ASSET PRICE");
  }
}
