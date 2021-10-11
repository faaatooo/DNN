const DNNToken = artifacts.require("DNNToken");

module.exports = function (deployer) {
  deployer.deploy(DNNToken);
};
