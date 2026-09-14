"use strict";

const createAggregationHooks = require("../../analyticalAggregation");

module.exports = createAggregationHooks({
    dimensions: ["SenderPartner", "IntegrationStatus", "CreationDate"],
    measures: ["IDocCount", "IDocErrorCount"],
    formulas: {
        // @AnalyticsDetails.query.formula de ZC_ResaIdocQuery.IntegrationRate
        IntegrationRate: (sums) =>
            sums.IDocCount > 0 ? ((sums.IDocCount - sums.IDocErrorCount) / sums.IDocCount) * 100 : 0
    },
    scales: {
        IntegrationRate: 1
    }
});
