"use strict";

const createAggregationHooks = require("../../analyticalAggregation");

module.exports = createAggregationHooks({
    dimensions: [
        "Plant",
        "PurchasingGroup",
        "OriginType",
        "OriginTypeText",
        "ChainStage",
        "ChainStageText",
        "PurReqDate",
        "Currency"
    ],
    measures: ["PurReqItemCount", "ConvertedItemCount", "OpenItemCount", "ItemAmount"],
    formulas: {
        // @AnalyticsDetails.query.formula de ZC_ResaChainQuery.ConversionRate
        ConversionRate: (sums) =>
            sums.PurReqItemCount > 0 ? (sums.ConvertedItemCount / sums.PurReqItemCount) * 100 : 0
    },
    scales: {
        ItemAmount: 3,
        ConversionRate: 1
    }
});
