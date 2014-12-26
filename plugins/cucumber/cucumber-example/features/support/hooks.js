module.exports = function() {
  this.After(function (scenario, callback) {
    if (scenario.isFailed()) {
      scenario.attach(create1MegabyteBuffer(), 'text/plain');
    }
    callback();
  });

  function create1MegabyteBuffer() {
    return new Buffer(1024 * 1024);
  }
};
