return {
    Locale = 'en',
    
    Machines = {
        { label = 'prop_vend_coffe_01', value = 'prop_vend_coffe_01' },
        { label = 'prop_vend_water_01', value = 'prop_vend_water_01' },
        -- you can add more
    },


    -- jobs that cant buy vending, if chosen type is "owned by job"
    BlacklsitedJobs = {
        ['unemployed'] = true,
    },

    -- items that cant be put for sale
    BlacklistedItems = {
        ['money'] = true,
        ['black_money'] = true,
    },

    -- items that cant be used as currency
    CantBeCurrency = {
        --['water'] = true
    },

    SellPertencage = 0.70 -- 70% of original price
}