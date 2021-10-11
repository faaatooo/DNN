const ReviewProcess = artifacts.require("ReviewProcess");

module.exports = function (deployer) {
  deployer.deploy(ReviewProcess);
};
