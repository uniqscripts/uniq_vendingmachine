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

    SellPertencage = 0.70 -- 70% of original price
}