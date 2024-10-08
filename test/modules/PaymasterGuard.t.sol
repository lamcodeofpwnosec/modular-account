// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {PackedUserOperation} from "@eth-infinitism/account-abstraction/interfaces/PackedUserOperation.sol";

import {TimeRangeAndPaymasterGuardModule} from "../../src/modules/permissions/TimeRangeAndPaymasterGuardModule.sol";

import {AccountTestBase} from "../utils/AccountTestBase.sol";

contract PaymasterGuardTest is AccountTestBase {
    TimeRangeAndPaymasterGuardModule public module = new TimeRangeAndPaymasterGuardModule();

    address public account;
    address public paymaster1;
    address public paymaster2;
    uint32 public constant ENTITY_ID = 1;

    function setUp() public override {
        account = payable(makeAddr("account"));
        paymaster1 = payable(makeAddr("paymaster1"));
        paymaster2 = payable(makeAddr("paymaster2"));
    }

    function test_onInstall() public withSMATest {
        vm.startPrank(address(account));
        module.onInstall(abi.encode(ENTITY_ID, uint48(0), uint48(0), paymaster1));

        (,, address paymaster) = module.timeRangeAndPaymasterGuards(ENTITY_ID, account);
        assertEq(paymaster1, paymaster);
    }

    function test_onUninstall() public withSMATest {
        vm.startPrank(address(account));
        module.onUninstall(abi.encode(ENTITY_ID));

        (,, address paymaster) = module.timeRangeAndPaymasterGuards(ENTITY_ID, account);
        assertEq(address(0), paymaster);
    }

    function test_preUserOpValidationHook_success() public withSMATest {
        PackedUserOperation memory uo = _packUO(abi.encodePacked(paymaster1, ""));

        vm.startPrank(address(account));
        // install the right paymaster
        module.onInstall(abi.encode(ENTITY_ID, uint48(0), uint48(0), paymaster1));
        uint256 res = module.preUserOpValidationHook(ENTITY_ID, uo, "");

        assertEq(res, 0);
    }

    function test_preUserOpValidationHook_failWithInvalidData() public withSMATest {
        PackedUserOperation memory uo = _packUO("");

        vm.startPrank(address(account));
        module.onInstall(abi.encode(ENTITY_ID, uint48(0), uint48(0), paymaster1));

        vm.expectRevert();
        module.preUserOpValidationHook(ENTITY_ID, uo, "");
    }

    function test_preUserOpValidationHook_fail() public withSMATest {
        PackedUserOperation memory uo = _packUO(abi.encodePacked(paymaster1, ""));

        vm.startPrank(address(account));
        // install the wrong paymaster
        module.onInstall(abi.encode(ENTITY_ID, uint48(0), uint48(0), paymaster2));

        vm.expectRevert(abi.encodeWithSelector(TimeRangeAndPaymasterGuardModule.BadPaymasterSpecified.selector));
        module.preUserOpValidationHook(ENTITY_ID, uo, "");
    }

    function test_preRuntimeValidationHook_success() public withSMATest {
        vm.startPrank(address(account));

        module.preRuntimeValidationHook(ENTITY_ID, address(0), 0, "", "");
    }

    function _packUO(bytes memory paymasterAndData) internal view returns (PackedUserOperation memory) {
        return PackedUserOperation({
            sender: account,
            nonce: 0,
            initCode: "",
            callData: abi.encodePacked(""),
            accountGasLimits: bytes32(bytes16(uint128(200_000))) | bytes32(uint256(200_000)),
            preVerificationGas: 200_000,
            gasFees: bytes32(uint256(uint128(0))),
            paymasterAndData: paymasterAndData,
            signature: ""
        });
    }
}