pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {ILendingPoolAddressesProvider} from '../interfaces/ILendingPoolAddressesProvider.sol';
import {IKlaybankIncentivesController} from '../interfaces/IKlaybankIncentivesController.sol';
import {IUiIncentiveDataProvider} from './interfaces/IUiIncentiveDataProvider.sol';
import {ILendingPool} from '../interfaces/ILendingPool.sol';
import {IBToken} from '../interfaces/IBToken.sol';
import {IVariableDebtToken} from '../interfaces/IVariableDebtToken.sol';
import {IStableDebtToken} from '../interfaces/IStableDebtToken.sol';
import {UserConfiguration} from '../protocol/libraries/configuration/UserConfiguration.sol';
import {DataTypes} from '../protocol/libraries/types/DataTypes.sol';

contract UiIncentiveDataProvider is IUiIncentiveDataProvider {
  using UserConfiguration for DataTypes.UserConfigurationMap;

  constructor() public {}

  function getFullReservesIncentiveData(ILendingPoolAddressesProvider provider, address user)
  external
  view
  override
  returns (AggregatedReserveIncentiveData[] memory, UserReserveIncentiveData[] memory)
  {
    return (_getReservesIncentivesData(provider), _getUserReservesIncentivesData(provider, user));
  }

  function getReservesIncentivesData(ILendingPoolAddressesProvider provider)
  external
  view
  override
  returns (AggregatedReserveIncentiveData[] memory)
  {
    return _getReservesIncentivesData(provider);
  }

  function _getReservesIncentivesData(ILendingPoolAddressesProvider provider)
  private
  view
  returns (AggregatedReserveIncentiveData[] memory)
  {
    ILendingPool lendingPool = ILendingPool(provider.getLendingPool());
    address[] memory reserves = lendingPool.getReservesList();
    AggregatedReserveIncentiveData[] memory reservesIncentiveData =
    new AggregatedReserveIncentiveData[](reserves.length);

    for (uint256 i = 0; i < reserves.length; i++) {
      AggregatedReserveIncentiveData memory reserveIncentiveData = reservesIncentiveData[i];
      reserveIncentiveData.underlyingAsset = reserves[i];

      DataTypes.ReserveData memory baseData = lendingPool.getReserveData(reserves[i]);

      IKlaybankIncentivesController aKlaybankIncentiveController =
      IBToken(baseData.bTokenAddress).getIncentivesController();
      reserveIncentiveData.aIncentiveData = _getBincentiveData(aKlaybankIncentiveController, baseData, reserves[i]);

      IKlaybankIncentivesController sTokenIncentiveController =
      IStableDebtToken(baseData.stableDebtTokenAddress).getIncentivesController();
      reserveIncentiveData.sIncentiveData = _getSincentiveData(sTokenIncentiveController, baseData, reserves[i]);

      IKlaybankIncentivesController vTokenIncentiveController =
      IVariableDebtToken(baseData.variableDebtTokenAddress).getIncentivesController();
      reserveIncentiveData.vIncentiveData =_getVincentiveData(vTokenIncentiveController, baseData, reserves[i]);
    }

    return (reservesIncentiveData);
  }

  function _getBincentiveData(IKlaybankIncentivesController aKlaybankIncentiveController, DataTypes.ReserveData memory baseData, address reserve) private
  view
  returns (IncentiveData memory){
    (
    uint256 aTokenIncentivesIndex,
    uint256[] memory aMonthlyEmissionPerSecond,
    ,
    uint256 aIncentivesLastUpdateTimestamp,
    ,
    ,
    ) = aKlaybankIncentiveController.getAssetData(baseData.bTokenAddress);

    return IncentiveData(
      aMonthlyEmissionPerSecond,
      aIncentivesLastUpdateTimestamp,
      aTokenIncentivesIndex,
      aKlaybankIncentiveController.getDistributionEndTimestamp(reserve),
      baseData.bTokenAddress,
      aKlaybankIncentiveController.REWARD_TOKEN()
    );
  }

  function _getSincentiveData(IKlaybankIncentivesController sTokenIncentiveController, DataTypes.ReserveData memory baseData, address reserve) private
  view
  returns (IncentiveData memory){
    (
    uint256 sTokenIncentivesIndex,
    uint256[] memory sMonthlyEmissionPerSecond,
    ,
    uint256 sIncentivesLastUpdateTimestamp,
    ,
    ,
    ) = sTokenIncentiveController.getAssetData(baseData.stableDebtTokenAddress);

    return IncentiveData(
      sMonthlyEmissionPerSecond,
      sIncentivesLastUpdateTimestamp,
      sTokenIncentivesIndex,
      sTokenIncentiveController.getDistributionEndTimestamp(reserve),
      baseData.stableDebtTokenAddress,
      sTokenIncentiveController.REWARD_TOKEN()
    );
  }

  function _getVincentiveData(IKlaybankIncentivesController vTokenIncentiveController, DataTypes.ReserveData memory baseData, address reserve) private
  view
  returns (IncentiveData memory){

    (
    uint256 vTokenIncentivesIndex,
    uint256[] memory vMonthlyEmissionPerSecond,
    ,
    uint256 vIncentivesLastUpdateTimestamp,
    ,
    ,
    ) = vTokenIncentiveController.getAssetData(baseData.variableDebtTokenAddress);

    return IncentiveData(
      vMonthlyEmissionPerSecond,
      vIncentivesLastUpdateTimestamp,
      vTokenIncentivesIndex,
      vTokenIncentiveController.getDistributionEndTimestamp(reserve),
      baseData.variableDebtTokenAddress,
      vTokenIncentiveController.REWARD_TOKEN()
    );
  }

  function getUserReservesIncentivesData(ILendingPoolAddressesProvider provider, address user)
  external
  view
  override
  returns (UserReserveIncentiveData[] memory)
  {
    return _getUserReservesIncentivesData(provider, user);
  }

  function _getUserReservesIncentivesData(ILendingPoolAddressesProvider provider, address user)
  private
  view
  returns (UserReserveIncentiveData[] memory)
  {
    ILendingPool lendingPool = ILendingPool(provider.getLendingPool());
    address[] memory reserves = lendingPool.getReservesList();

    UserReserveIncentiveData[] memory userReservesIncentivesData =
    new UserReserveIncentiveData[](user != address(0) ? reserves.length : 0);

    for (uint256 i = 0; i < reserves.length; i++) {
      DataTypes.ReserveData memory baseData = lendingPool.getReserveData(reserves[i]);

      // user reserve data
      userReservesIncentivesData[i].underlyingAsset = reserves[i];

      IKlaybankIncentivesController aKlaybankIncentiveController =
      IBToken(baseData.bTokenAddress).getIncentivesController();

      IUiIncentiveDataProvider.UserIncentiveData memory aUserIncentiveData;
      aUserIncentiveData.tokenincentivesUserIndex = aKlaybankIncentiveController.getUserAssetData(
        user,
        baseData.bTokenAddress
      );
      aUserIncentiveData.userUnclaimedRewards = aKlaybankIncentiveController.getUserUnclaimedRewards(
        user
      );
      aUserIncentiveData.tokenAddress = baseData.bTokenAddress;
      aUserIncentiveData.rewardTokenAddress = aKlaybankIncentiveController.REWARD_TOKEN();

      userReservesIncentivesData[i].aTokenIncentivesUserData = aUserIncentiveData;

      IKlaybankIncentivesController vTokenIncentiveController =
      IVariableDebtToken(baseData.variableDebtTokenAddress).getIncentivesController();
      UserIncentiveData memory vUserIncentiveData;
      vUserIncentiveData.tokenincentivesUserIndex = vTokenIncentiveController.getUserAssetData(
        user,
        baseData.variableDebtTokenAddress
      );
      vUserIncentiveData.userUnclaimedRewards = vTokenIncentiveController.getUserUnclaimedRewards(
        user
      );
      vUserIncentiveData.tokenAddress = baseData.variableDebtTokenAddress;
      vUserIncentiveData.rewardTokenAddress = vTokenIncentiveController.REWARD_TOKEN();

      userReservesIncentivesData[i].vTokenIncentivesUserData = vUserIncentiveData;

      IKlaybankIncentivesController sTokenIncentiveController =
      IStableDebtToken(baseData.stableDebtTokenAddress).getIncentivesController();
      UserIncentiveData memory sUserIncentiveData;
      sUserIncentiveData.tokenincentivesUserIndex = sTokenIncentiveController.getUserAssetData(
        user,
        baseData.stableDebtTokenAddress
      );
      sUserIncentiveData.userUnclaimedRewards = sTokenIncentiveController.getUserUnclaimedRewards(
        user
      );
      sUserIncentiveData.tokenAddress = baseData.stableDebtTokenAddress;
      sUserIncentiveData.rewardTokenAddress = sTokenIncentiveController.REWARD_TOKEN();

      userReservesIncentivesData[i].sTokenIncentivesUserData = sUserIncentiveData;
    }

    return (userReservesIncentivesData);
  }
}
