pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {ILendingPoolAddressesProvider} from '../../interfaces/ILendingPoolAddressesProvider.sol';

interface IUiIncentiveDataProvider {
  struct AggregatedReserveIncentiveData {
    address underlyingAsset;
    IncentiveData aIncentiveData;
    IncentiveData vIncentiveData;
    IncentiveData sIncentiveData;
  }

  struct IncentiveData {
    uint256[] MonthlyEmissionPerSecond;
    uint256 incentivesLastUpdateTimestamp;
    uint256 tokenIncentivesIndex;
    uint256 emissionEndTimestamp;
    address tokenAddress;
    address rewardTokenAddress;
  }

  struct UserReserveIncentiveData {
    address underlyingAsset;
    UserIncentiveData aTokenIncentivesUserData;
    UserIncentiveData vTokenIncentivesUserData;
    UserIncentiveData sTokenIncentivesUserData;
  }

  struct UserIncentiveData {
    uint256 tokenincentivesUserIndex;
    uint256 userUnclaimedRewards;
    address tokenAddress;
    address rewardTokenAddress;
  }

  function getReservesIncentivesData(ILendingPoolAddressesProvider provider)
  external
  view
  returns (AggregatedReserveIncentiveData[] memory);

  function getUserReservesIncentivesData(ILendingPoolAddressesProvider provider, address user)
  external
  view
  returns (UserReserveIncentiveData[] memory);

  // generic method with full data
  function getFullReservesIncentiveData(ILendingPoolAddressesProvider provider, address user)
  external
  view
  returns (AggregatedReserveIncentiveData[] memory, UserReserveIncentiveData[] memory);
}
