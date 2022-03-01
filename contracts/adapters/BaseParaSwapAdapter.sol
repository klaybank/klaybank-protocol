// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {SafeMath} from '../dependencies/openzeppelin/contracts/SafeMath.sol';
import {IKIP7} from '../dependencies/openzeppelin/contracts/IKIP7.sol';
import {IKIP7Detailed} from '../dependencies/openzeppelin/contracts/IKIP7Detailed.sol';
import {SafeKIP7} from '../dependencies/openzeppelin/contracts/SafeKIP7.sol';
import {Ownable} from '../dependencies/openzeppelin/contracts/Ownable.sol';
import {ILendingPoolAddressesProvider} from '../interfaces/ILendingPoolAddressesProvider.sol';
import {DataTypes} from '../protocol/libraries/types/DataTypes.sol';
import {IPriceOracleGetter} from '../interfaces/IPriceOracleGetter.sol';
import {IKIP7WithPermit} from '../interfaces/IKIP7WithPermit.sol';
import {FlashLoanReceiverBase} from '../flashloan/base/FlashLoanReceiverBase.sol';

/**
 * @title BaseParaSwapAdapter
 * @notice Utility functions for adapters using ParaSwap
 * @author Jason Raymond Bell
 */
abstract contract BaseParaSwapAdapter is FlashLoanReceiverBase, Ownable {
  using SafeMath for uint256;
  using SafeKIP7 for IKIP7;
  using SafeKIP7 for IKIP7Detailed;
  using SafeKIP7 for IKIP7WithPermit;

  struct PermitSignature {
    uint256 amount;
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
  }

  // Max slippage percent allowed
  uint256 public constant MAX_SLIPPAGE_PERCENT = 3000; // 30%

  IPriceOracleGetter public immutable ORACLE;

  event Swapped(address indexed fromAsset, address indexed toAsset, uint256 fromAmount, uint256 receivedAmount);

  constructor(
    ILendingPoolAddressesProvider addressesProvider
  ) public FlashLoanReceiverBase(addressesProvider) {
    ORACLE = IPriceOracleGetter(addressesProvider.getPriceOracle());
  }

  /**
   * @dev Get the price of the asset from the oracle denominated in eth
   * @param asset address
   * @return eth price for the asset
   */
  function _getPrice(address asset) internal view returns (uint256) {
    return ORACLE.getAssetPrice(asset);
  }

  /**
   * @dev Get the decimals of an asset
   * @return number of decimals of the asset
   */
  function _getDecimals(IKIP7Detailed asset) internal view returns (uint8) {
    uint8 decimals = asset.decimals();
    // Ensure 10**decimals won't overflow a uint256
    require(decimals <= 77, 'TOO_MANY_DECIMALS_ON_TOKEN');
    return decimals;
  }

  /**
   * @dev Get the bToken associated to the asset
   * @return address of the bToken
   */
  function _getReserveData(address asset) internal view returns (DataTypes.ReserveData memory) {
    return LENDING_POOL.getReserveData(asset);
  }

  /**
   * @dev Pull the BTokens from the user
   * @param reserve address of the asset
   * @param reserveBToken address of the bToken of the reserve
   * @param user address
   * @param amount of tokens to be transferred to the contract
   * @param permitSignature struct containing the permit signature
   */
  function _pullBTokenAndWithdraw(
    address reserve,
    IKIP7WithPermit reserveBToken,
    address user,
    uint256 amount,
    PermitSignature memory permitSignature
  ) internal {
    // If deadline is set to zero, assume there is no signature for permit
    if (permitSignature.deadline != 0) {
      reserveBToken.permit(
        user,
        address(this),
        permitSignature.amount,
        permitSignature.deadline,
        permitSignature.v,
        permitSignature.r,
        permitSignature.s
      );
    }

    // transfer from user to adapter
    reserveBToken.safeTransferFrom(user, address(this), amount);

    // withdraw reserve
    require(
      LENDING_POOL.withdraw(reserve, amount, address(this)) == amount,
      'UNEXPECTED_AMOUNT_WITHDRAWN'
    );
  }

  /**
   * @dev Emergency rescue for token stucked on this contract, as failsafe mechanism
   * - Funds should never remain in this contract more time than during transactions
   * - Only callable by the owner
   */
  function rescueTokens(IKIP7 token) external onlyOwner {
    token.safeTransfer(owner(), token.balanceOf(address(this)));
  }
}