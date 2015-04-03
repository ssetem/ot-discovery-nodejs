testUtils = {
  timeDiffMS: function(date1, date2) {
  	return Math.abs(date2.getTime() - date1.getTime());
  }
};

module.exports = testUtils;