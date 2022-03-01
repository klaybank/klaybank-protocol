// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import {ILendingPool} from './ILendingPool.sol';
import {IKlaybankIncentivesController} from './IKlaybankIncentivesController.sol';

/**
 * @title IInitializableBToken
 * @notice Interface for the initialize function on BToken
 * @author Aave
 **/
interface IInitializableBToken {
  /**
   * @dev Emitted when an bToken is initialized
   * @param underlyingAsset The address of the underlying asset
   * @param pool The address of the associated lending pool
   * @param treasury The address of the treasury
   * @param incentivesController The address of the incentives controller for this bToken
   * @param bTokenDecimals the decimals of the underlying
   * @param bTokenName the name of the bToken
   * @param bTokenSymbol the symbol of the bToken
   * @param params A set of encoded parameters for additional initialization
   **/
  event Initialized(
    address indexed underlyingAsset,
    address indexed pool,
    address treasury,
    address incentivesController,
    uint8 bTokenDecimals,
    string bTokenName,
    string bTokenSymbol,
    bytes params
  );

  /**
   * @dev Initializes the bToken
   * @param pool The address of the lending pool where this bToken will be used
   * @param treasury The address of the Klaybank treasury, receiving the fees on this bToken
   * @param underlyingAsset The address of the underlying asset of this bToken (E.g. WETH for aWETH)
   * @param incentivesController The smart contract managing potential incentives distribution
   * @param bTokenDecimals The decimals of the bToken, same as the underlying asset's
   * @param bTokenName The name of the bToken
   * @param bTokenSymbol The symbol of the bToken
   */
  function initialize(
    ILendingPool pool,
    address treasury,
    address underlyingAsset,
    IKlaybankIncentivesController incentivesController,
    uint8 bTokenDecimals,
    string calldata bTokenName,
    string calldata bTokenSymbol,
    bytes calldata params,
    uint256 chainId
  ) external;
}
