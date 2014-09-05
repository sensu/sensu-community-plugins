module.exports = function() {
  this.When(/^a failing action is executed$/, function(callback) {
    if (this.isDryRun()) { return callback(); }

    callback('Failed');
  });
};
