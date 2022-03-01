pragma solidity 0.6.12;

import "./IPriceOracleGetter.sol";

interface IKlaybankOracle is IPriceOracleGetter {

  function getKlayUsdPrice() external view returns (uint256);

  function getAssetPriceInUsd(address _asset) external view returns (uint256);
}
