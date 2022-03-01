// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {IKIP7Detailed} from '../dependencies/openzeppelin/contracts/IKIP7Detailed.sol';
import {ILendingPoolAddressesProvider} from '../interfaces/ILendingPoolAddressesProvider.sol';
import {IKlaybankIncentivesController} from '../interfaces/IKlaybankIncentivesController.sol';
import {IUiPoolDataProvider} from './interfaces/IUiPoolDataProvider.sol';
import {ILendingPool} from '../interfaces/ILendingPool.sol';
import {IPriceOracleGetter} from '../interfaces/IPriceOracleGetter.sol';
import {IBToken} from '../interfaces/IBToken.sol';
import {IVariableDebtToken} from '../interfaces/IVariableDebtToken.sol';
import {IStableDebtToken} from '../interfaces/IStableDebtToken.sol';
import {WadRayMath} from '../protocol/libraries/math/WadRayMath.sol';
import {ReserveConfiguration} from '../protocol/libraries/configuration/ReserveConfiguration.sol';
import {UserConfiguration} from '../protocol/libraries/configuration/UserConfiguration.sol';
import {DataTypes} from '../protocol/libraries/types/DataTypes.sol';
import {SafeMath} from '../dependencies/openzeppelin/contracts/SafeMath.sol';
import {
  DefaultReserveInterestRateStrategy
} from '../protocol/lendingpool/DefaultReserveInterestRateStrategy.sol';
import {IKlaybankOracle} from "../interfaces/IKlaybankOracle.sol";

contract UiPoolDataProvider is IUiPoolDataProvider {
  using SafeMath for uint256;
  using WadRayMath for uint256;
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
  using UserConfiguration for DataTypes.UserConfigurationMap;

  IKlaybankIncentivesController public immutable override incentivesController;
  IKlaybankOracle public immutable oracle;
  uint256 constant SECONDS_OF_ONE_MONTH = 30 * 24 * 60 * 60;

  constructor(IKlaybankIncentivesController _incentivesController, IKlaybankOracle _oracle) public {
    incentivesController = _incentivesController;
    oracle = _oracle;
  }

  function getInterestRateStrategySlopes(DefaultReserveInterestRateStrategy interestRateStrategy)
    internal
    view
    returns (
      uint256,
      uint256,
      uint256,
      uint256
    )
  {
    return (
      interestRateStrategy.variableRateSlope1(),
      interestRateStrategy.variableRateSlope2(),
      interestRateStrategy.stableRateSlope1(),
      interestRateStrategy.stableRateSlope2()
    );
  }

  function getReservesList(ILendingPoolAddressesProvider provider)
    public
    view
    override
    returns (address[] memory)
  {
    ILendingPool lendingPool = ILendingPool(provider.getLendingPool());
    return lendingPool.getReservesList();
  }

  function getSimpleReservesData(ILendingPoolAddressesProvider provider)
    public
    view
    override
    returns (
      AggregatedReserveData[] memory,
      uint256
    )
  {
    ILendingPool lendingPool = ILendingPool(provider.getLendingPool());
    address[] memory reserves = lendingPool.getReservesList();
    AggregatedReserveData[] memory reservesData = new AggregatedReserveData[](reserves.length);

    for (uint256 i = 0; i < reserves.length; i++) {
      AggregatedReserveData memory reserveData = reservesData[i];
      reserveData.underlyingAsset = reserves[i];

      // reserve current state
      DataTypes.ReserveData memory baseData =
        lendingPool.getReserveData(reserveData.underlyingAsset);
      reserveData.liquidityIndex = baseData.liquidityIndex;
      reserveData.variableBorrowIndex = baseData.variableBorrowIndex;
      reserveData.liquidityRate = baseData.currentLiquidityRate;
      reserveData.variableBorrowRate = baseData.currentVariableBorrowRate;
      reserveData.stableBorrowRate = baseData.currentStableBorrowRate;
      reserveData.lastUpdateTimestamp = baseData.lastUpdateTimestamp;
      reserveData.bTokenAddress = baseData.bTokenAddress;
      reserveData.stableDebtTokenAddress = baseData.stableDebtTokenAddress;
      reserveData.variableDebtTokenAddress = baseData.variableDebtTokenAddress;
      reserveData.interestRateStrategyAddress = baseData.interestRateStrategyAddress;
      reserveData.priceInEth = oracle.getAssetPrice(reserveData.underlyingAsset);

      reserveData.availableLiquidity = IKIP7Detailed(reserveData.underlyingAsset).balanceOf(
        reserveData.bTokenAddress
      );
      (
        reserveData.totalPrincipalStableDebt,
        ,
        reserveData.averageStableRate,
        reserveData.stableDebtLastUpdateTimestamp
      ) = IStableDebtToken(reserveData.stableDebtTokenAddress).getSupplyData();
      reserveData.totalScaledVariableDebt = IVariableDebtToken(reserveData.variableDebtTokenAddress)
        .scaledTotalSupply();

      // reserve configuration

      // we're getting this info from the bToken, because some of assets can be not compliant with ETC20Detailed
      reserveData.symbol = IKIP7Detailed(reserveData.underlyingAsset).symbol();
      reserveData.name = '';

      (
        reserveData.baseLTVasCollateral,
        reserveData.reserveLiquidationThreshold,
        reserveData.reserveLiquidationBonus,
        reserveData.decimals,
        reserveData.reserveFactor
      ) = baseData.configuration.getParamsMemory();
      (
        reserveData.isActive,
        reserveData.isFrozen,
        reserveData.borrowingEnabled,
        reserveData.stableBorrowRateEnabled
      ) = baseData.configuration.getFlagsMemory();
      reserveData.usageAsCollateralEnabled = reserveData.baseLTVasCollateral != 0;
      (
        reserveData.variableRateSlope1,
        reserveData.variableRateSlope2,
        reserveData.stableRateSlope1,
        reserveData.stableRateSlope2
      ) = getInterestRateStrategySlopes(
        DefaultReserveInterestRateStrategy(reserveData.interestRateStrategyAddress)
      );

      // incentives
      if (address(0) != address(incentivesController)) {
        (
          reserveData.bTokenIncentivesIndex,
          reserveData.bMonthlyEmissionPerSecond,
          ,
          reserveData.bIncentivesLastUpdateTimestamp,
          ,
          ,
        ) = incentivesController.getAssetData(reserveData.bTokenAddress);
        reserveData.bEmissionPerSecond = getCurrentEmissionPerSecond(
            incentivesController.getDistributionEndTimestamp(reserveData.bTokenAddress),
            reserveData.bMonthlyEmissionPerSecond,
            incentivesController.getDistributionStartTimestamp(reserveData.bTokenAddress)
        );
        reserveData.bTokenDistributionEndTimestamp = incentivesController.getDistributionEndTimestamp(reserveData.bTokenAddress);
        reserveData.bCurrentShareRatio = incentivesController.getCurrentShareRatio(reserveData.bTokenAddress);

        (
          reserveData.sTokenIncentivesIndex,
          reserveData.sMonthlyEmissionPerSecond,
          ,
          reserveData.sIncentivesLastUpdateTimestamp,
          ,
          ,
        ) = incentivesController.getAssetData(reserveData.stableDebtTokenAddress);
        reserveData.sEmissionPerSecond = getCurrentEmissionPerSecond(
            incentivesController.getDistributionEndTimestamp(reserveData.stableDebtTokenAddress),
            reserveData.sMonthlyEmissionPerSecond,
            incentivesController.getDistributionStartTimestamp(reserveData.stableDebtTokenAddress)
        );
        reserveData.sTokenDistributionEndTimestamp = incentivesController.getDistributionEndTimestamp(reserveData.stableDebtTokenAddress);
        reserveData.sCurrentShareRatio = incentivesController.getCurrentShareRatio(reserveData.stableDebtTokenAddress);

        (
          reserveData.vTokenIncentivesIndex,
          reserveData.vMonthlyEmissionPerSecond,
          ,
          reserveData.vIncentivesLastUpdateTimestamp,
          ,
          ,
        ) = incentivesController.getAssetData(reserveData.variableDebtTokenAddress);
        reserveData.vEmissionPerSecond = getCurrentEmissionPerSecond(
            incentivesController.getDistributionEndTimestamp(reserveData.variableDebtTokenAddress),
            reserveData.vMonthlyEmissionPerSecond,
            incentivesController.getDistributionStartTimestamp(reserveData.variableDebtTokenAddress)
        );
        reserveData.vTokenDistributionEndTimestamp = incentivesController.getDistributionEndTimestamp(reserveData.variableDebtTokenAddress);
        reserveData.vCurrentShareRatio = incentivesController.getCurrentShareRatio(reserveData.variableDebtTokenAddress);
      }
    }

    return (reservesData, oracle.getKlayUsdPrice()); // todo fix usd
  }

  function getCurrentEmissionPerSecond(uint256 distributionEnd, uint256[] memory monthlyEmissionPerSecond, uint256 distributionStart) internal view returns (uint256) {
    uint256 currentTimestamp = block.timestamp > distributionEnd ? distributionEnd : block.timestamp;
    uint256 distributedTime;
    if (distributionStart > currentTimestamp) {
      return 0;
    } else {
      distributedTime = currentTimestamp.sub(distributionStart);
      uint256 currentMonthIndex = distributedTime.div(SECONDS_OF_ONE_MONTH);
      if (currentMonthIndex != 0 && currentMonthIndex == monthlyEmissionPerSecond.length) {
        currentMonthIndex = currentMonthIndex - 1;
      }

      if (monthlyEmissionPerSecond.length == 0){
        return 0;
      }else{
        return monthlyEmissionPerSecond[currentMonthIndex];
      }
    }

    return 0;
  }

  function getUserReservesData(ILendingPoolAddressesProvider provider, address user)
    external
    view
    override
    returns (UserReserveData[] memory, uint256)
  {
    ILendingPool lendingPool = ILendingPool(provider.getLendingPool());
    address[] memory reserves = lendingPool.getReservesList();
    DataTypes.UserConfigurationMap memory userConfig = lendingPool.getUserConfiguration(user);

    UserReserveData[] memory userReservesData =
      new UserReserveData[](user != address(0) ? reserves.length : 0);

    for (uint256 i = 0; i < reserves.length; i++) {
      DataTypes.ReserveData memory baseData = lendingPool.getReserveData(reserves[i]);
      // incentives
      if (address(0) != address(incentivesController)) {
        userReservesData[i].bTokenincentivesUserIndex = incentivesController.getUserAssetData(
          user,
          baseData.bTokenAddress
        );
        userReservesData[i].vTokenincentivesUserIndex = incentivesController.getUserAssetData(
          user,
          baseData.variableDebtTokenAddress
        );
        userReservesData[i].sTokenincentivesUserIndex = incentivesController.getUserAssetData(
          user,
          baseData.stableDebtTokenAddress
        );
      }
      // user reserve data
      userReservesData[i].underlyingAsset = reserves[i];
      userReservesData[i].scaledBTokenBalance = IBToken(baseData.bTokenAddress).scaledBalanceOf(
        user
      );
      userReservesData[i].usageAsCollateralEnabledOnUser = userConfig.isUsingAsCollateral(i);

      if (userConfig.isBorrowing(i)) {
        userReservesData[i].scaledVariableDebt = IVariableDebtToken(
          baseData
            .variableDebtTokenAddress
        )
          .scaledBalanceOf(user);
        userReservesData[i].principalStableDebt = IStableDebtToken(baseData.stableDebtTokenAddress)
          .principalBalanceOf(user);
        if (userReservesData[i].principalStableDebt != 0) {
          userReservesData[i].stableBorrowRate = IStableDebtToken(baseData.stableDebtTokenAddress)
            .getUserStableRate(user);
          userReservesData[i].stableBorrowLastUpdateTimestamp = IStableDebtToken(
            baseData
              .stableDebtTokenAddress
          )
            .getUserLastUpdated(user);
        }
      }
    }

    uint256 userUnclaimedRewards;
    if (address(0) != address(incentivesController)) {
      userUnclaimedRewards = incentivesController.getUserUnclaimedRewards(user);
    }

    return (userReservesData, userUnclaimedRewards);
  }

  function getReservesData(ILendingPoolAddressesProvider provider, address user)
    external
    view
    override
    returns (
      AggregatedReserveData[] memory,
      UserReserveData[] memory,
      uint256,
      IncentivesControllerData memory
    )
  {
    ILendingPool lendingPool = ILendingPool(provider.getLendingPool());
    address[] memory reserves = lendingPool.getReservesList();
    DataTypes.UserConfigurationMap memory userConfig = lendingPool.getUserConfiguration(user);

    AggregatedReserveData[] memory reservesData = new AggregatedReserveData[](reserves.length);
    UserReserveData[] memory userReservesData =
      new UserReserveData[](user != address(0) ? reserves.length : 0);

    for (uint256 i = 0; i < reserves.length; i++) {
      AggregatedReserveData memory reserveData = reservesData[i];
      reserveData.underlyingAsset = reserves[i];

      // reserve current state
      DataTypes.ReserveData memory baseData =
        lendingPool.getReserveData(reserveData.underlyingAsset);
      reserveData.liquidityIndex = baseData.liquidityIndex;
      reserveData.variableBorrowIndex = baseData.variableBorrowIndex;
      reserveData.liquidityRate = baseData.currentLiquidityRate;
      reserveData.variableBorrowRate = baseData.currentVariableBorrowRate;
      reserveData.stableBorrowRate = baseData.currentStableBorrowRate;
      reserveData.lastUpdateTimestamp = baseData.lastUpdateTimestamp;
      reserveData.bTokenAddress = baseData.bTokenAddress;
      reserveData.stableDebtTokenAddress = baseData.stableDebtTokenAddress;
      reserveData.variableDebtTokenAddress = baseData.variableDebtTokenAddress;
      reserveData.interestRateStrategyAddress = baseData.interestRateStrategyAddress;
      reserveData.priceInEth = oracle.getAssetPrice(reserveData.underlyingAsset);

      reserveData.availableLiquidity = IKIP7Detailed(reserveData.underlyingAsset).balanceOf(
        reserveData.bTokenAddress
      );
      (
        reserveData.totalPrincipalStableDebt,
        ,
        reserveData.averageStableRate,
        reserveData.stableDebtLastUpdateTimestamp
      ) = IStableDebtToken(reserveData.stableDebtTokenAddress).getSupplyData();
      reserveData.totalScaledVariableDebt = IVariableDebtToken(reserveData.variableDebtTokenAddress)
        .scaledTotalSupply();

      // reserve configuration

      // we're getting this info from the bToken, because some of assets can be not compliant with ETC20Detailed
      reserveData.symbol = IKIP7Detailed(reserveData.underlyingAsset).symbol();
      reserveData.name = '';

      (
        reserveData.baseLTVasCollateral,
        reserveData.reserveLiquidationThreshold,
        reserveData.reserveLiquidationBonus,
        reserveData.decimals,
        reserveData.reserveFactor
      ) = baseData.configuration.getParamsMemory();
      (
        reserveData.isActive,
        reserveData.isFrozen,
        reserveData.borrowingEnabled,
        reserveData.stableBorrowRateEnabled
      ) = baseData.configuration.getFlagsMemory();
      reserveData.usageAsCollateralEnabled = reserveData.baseLTVasCollateral != 0;
      (
        reserveData.variableRateSlope1,
        reserveData.variableRateSlope2,
        reserveData.stableRateSlope1,
        reserveData.stableRateSlope2
      ) = getInterestRateStrategySlopes(
        DefaultReserveInterestRateStrategy(reserveData.interestRateStrategyAddress)
      );

      // incentives
      if (address(0) != address(incentivesController)) {
        (
          reserveData.bTokenIncentivesIndex,
          reserveData.bMonthlyEmissionPerSecond,
          ,
          reserveData.bIncentivesLastUpdateTimestamp,
          ,
          ,
        ) = incentivesController.getAssetData(reserveData.bTokenAddress);
        reserveData.bEmissionPerSecond = getCurrentEmissionPerSecond(
          incentivesController.getDistributionEndTimestamp(reserveData.bTokenAddress),
          reserveData.bMonthlyEmissionPerSecond,
          incentivesController.getDistributionStartTimestamp(reserveData.bTokenAddress)
        );
        reserveData.bTokenDistributionEndTimestamp = incentivesController.getDistributionEndTimestamp(reserveData.bTokenAddress);
        reserveData.bCurrentShareRatio = incentivesController.getCurrentShareRatio(reserveData.bTokenAddress);

        (
          reserveData.sTokenIncentivesIndex,
          reserveData.sMonthlyEmissionPerSecond,
          ,
          reserveData.sIncentivesLastUpdateTimestamp,
          ,
          ,
        ) = incentivesController.getAssetData(reserveData.stableDebtTokenAddress);
        reserveData.sEmissionPerSecond = getCurrentEmissionPerSecond(
          incentivesController.getDistributionEndTimestamp(reserveData.stableDebtTokenAddress),
          reserveData.sMonthlyEmissionPerSecond,
          incentivesController.getDistributionStartTimestamp(reserveData.stableDebtTokenAddress)
        );
        reserveData.sTokenDistributionEndTimestamp = incentivesController.getDistributionEndTimestamp(reserveData.stableDebtTokenAddress);
        reserveData.sCurrentShareRatio = incentivesController.getCurrentShareRatio(reserveData.stableDebtTokenAddress);

        (
          reserveData.vTokenIncentivesIndex,
          reserveData.vMonthlyEmissionPerSecond,
          ,
          reserveData.vIncentivesLastUpdateTimestamp,
          ,
          ,
        ) = incentivesController.getAssetData(reserveData.variableDebtTokenAddress);
        reserveData.vEmissionPerSecond = getCurrentEmissionPerSecond(
          incentivesController.getDistributionEndTimestamp(reserveData.variableDebtTokenAddress),
          reserveData.vMonthlyEmissionPerSecond,
          incentivesController.getDistributionStartTimestamp(reserveData.variableDebtTokenAddress)
        );
        reserveData.vTokenDistributionEndTimestamp = incentivesController.getDistributionEndTimestamp(reserveData.variableDebtTokenAddress);
        reserveData.vCurrentShareRatio = incentivesController.getCurrentShareRatio(reserveData.variableDebtTokenAddress);
      }

      if (user != address(0)) {
        // incentives
        if (address(0) != address(incentivesController)) {
          userReservesData[i].bTokenincentivesUserIndex = incentivesController.getUserAssetData(
            user,
            reserveData.bTokenAddress
          );
          userReservesData[i].vTokenincentivesUserIndex = incentivesController.getUserAssetData(
            user,
            reserveData.variableDebtTokenAddress
          );
          userReservesData[i].sTokenincentivesUserIndex = incentivesController.getUserAssetData(
            user,
            reserveData.stableDebtTokenAddress
          );
        }
        // user reserve data
        userReservesData[i].underlyingAsset = reserveData.underlyingAsset;
        userReservesData[i].scaledBTokenBalance = IBToken(reserveData.bTokenAddress)
          .scaledBalanceOf(user);
        userReservesData[i].usageAsCollateralEnabledOnUser = userConfig.isUsingAsCollateral(i);

        if (userConfig.isBorrowing(i)) {
          userReservesData[i].scaledVariableDebt = IVariableDebtToken(
            reserveData
              .variableDebtTokenAddress
          )
            .scaledBalanceOf(user);
          userReservesData[i].principalStableDebt = IStableDebtToken(
            reserveData
              .stableDebtTokenAddress
          )
            .principalBalanceOf(user);
          if (userReservesData[i].principalStableDebt != 0) {
            userReservesData[i].stableBorrowRate = IStableDebtToken(
              reserveData
                .stableDebtTokenAddress
            )
              .getUserStableRate(user);
            userReservesData[i].stableBorrowLastUpdateTimestamp = IStableDebtToken(
              reserveData
                .stableDebtTokenAddress
            )
              .getUserLastUpdated(user);
          }
        }
      }
    }

    IncentivesControllerData memory incentivesControllerData;

    if (address(0) != address(incentivesController)) {
      if (user != address(0)) {
        incentivesControllerData.userUnclaimedRewards = incentivesController
        .getUserUnclaimedRewards(user);
      }
    }

    return (
      reservesData,
      userReservesData,
      oracle.getKlayUsdPrice(),
      incentivesControllerData
    );
  }
}
