let BN = web3.utils.BN;
let DNN = artifacts.require("./DNN.sol");
let { catchRevert } = require("./exceptionsHelpers.js");
const { items: ItemStruct, isDefined, isPayable, isType } = require("./ast-helper");

contract("DNN", function (accounts) {
	const [_writer, _reviewer, _publisher, _reader] = accounts;
	const emptyAddress = "0x0000000000000000000000000000000000000000";
	const REQUIRED_VOTER_REQUESTS = 10;
    const REQUIRED_VOTERS = 7;
    const WRITER_FEE = 100;
    const VOTING_PERIOD_DURATION = 3 days;
    address dnnTokenAddress;
    address userContractAddress;
    DNNToken dnnToken;
    User userContract;
    address voterAddress;
  
  let instance;

  beforeEach(async () => {
    instance = await DNN.new();
  });

  describe("Variables", () => {
    it("should have an owner", async () => {
      assert.equal(await instance.owner, contractOwner, "the contract has no owner");
    });

    describe("enum VoteStatus", () => {
      let enumVoteStatus;
      before(() => {
        enumVoteStatus = DNN.enums.VoteStatus;
        assert(
          enumVoteStatus,
          "The contract should define an Enum called VoteStatus"
        );
      });

      it("should define `none`", () => {
        assert(
          enumVoteStatus.hasOwnProperty('none'),
          "The enum does not have a `none` value"
        );
      });

      it("should define `accept`", () => {
        assert(
          enumVoteStatus.hasOwnProperty('accept'),
          "The enum does not have a `accept` value"
        );
      });

      it("should define `reject`", () => {
        assert(
          enumVoteStatus.hasOwnProperty('reject'),
          "The enum does not have a `reject` value"
        );
      });
	});

describe("enum ArticleStatus", () => {
      let enumArticleStatus;
      before(() => {
        enumArticleStatus = DNN.enums.ArticleStatus;
        assert(
          enumArticleStatus,
          "The contract should define an Enum called ArticleStatus"
        );
      });

      it("should define `none`", () => {
        assert(
          enumArticleStatus.hasOwnProperty('none'),
          "The enum does not have a `none` value"
        );
      });

      it("should define `waitingForVoters`", () => {
        assert(
          enumArticleStatus.hasOwnProperty('waitingForVoters'),
          "The enum does not have a `waitingForVoters` value"
        );
      });

      it("should define `voting`", () => {
        assert(
          enumArticleStatus.hasOwnProperty('voting'),
          "The enum does not have a `voting` value"
        );
      });
	  
	  it("should define `done`", () => {
        assert(
          enumArticleStatus.hasOwnProperty('done'),
          "The enum does not have a `done` value"
        );
      });
	});
