Locales['en'] = {
    commands = {
        addvending = 'Command that helps you create ownable vending machine',
        dellvending = 'Command that helps you to delete vendings',
        findvending = 'Command that teleports you to desired vending'
    },
    notify = {
        not_enough_money = 'You don\'t have enough money to buy this Vending Machine ($%s)',
        vending_bought = 'You have bought Vending Machine "%s" for $%s',
        vending_sold = 'You have sold Vending Machine "%s" for $%s',
        no_targeted_owner = 'Could not find targeted owner',
        vending_created = 'You have created Vending Machine "%s". Price: $%s',
        cant_put = 'You cant\'t put this item for sale',
        no_vendings = 'There is no created vendings'
    },
    context = {
        vending_title = 'Vending Machine',
        vending_settings = 'Vending Settings',
        money = 'Money',
        update_stock = 'Update Stock',
        stock_price = 'Stock: %s | Price: $%s',
        item_price = 'Item Price',
        item_stock = 'Item Stock',
        item_currency = 'Item to be used as currency',
        items = 'Items',
        buy_vending = 'Buy Vending Machine',
        sell_vending = 'Sell Vending Machine',
        manage_vending = 'Manage Vending Machine',
        access_vending = 'Access Vending',
        item_price_per_one = 'Price per item',
        currency = 'Currency',
        currency_desc = 'If you leave empty then currency will be money',
        stock = 'Vending Stock'
    },
    alert = {
        buy_vending_confirm = 'Would you like to buy this Vending Machine for $%s?',
        sell_vending_confirm = 'Would you like to send this Vending Machine for $%s?',
    },
    input = {
        vending_creator = 'Vending Machine Creator',
        vending_label = 'Label',
        vending_price = 'Price',
        select_object = 'Select Object',
        blip = 'Add Blip?',
        blipInput = {
            a = 'Sprite',
            b = 'Scale',
            c = 'Colour',
            d = 'Blip Name',
        },
        owned_type = {
            title = 'Chose Type',
            desc = 'If you leave input empty then vending will go for sale',
            a = 'Owned by player',
            b = 'Owned by job'
        },
        player_owned_label = 'Chose Player',
        player_owned_desc = 'If you leave input empty then vending will go for sale',
        job_owned_label = 'Chose Job',
        job_owned_desc = 'If you leave input empty then vending will go for sale, if type is owned by job then when player buys vending it will apply to his job',
        chose_grade = 'Chose Grade',
        chose_grade_desc = 'Minimal grade that will have access vending managment'
    },
    text_ui = {
        help = {
            ('By moving your mouse you are moving the object  \n'),
            ('[←] - Rotate the object left  \n'),
            ('[→] - Rotate the object right  \n'),
            ('[ENTER] - Finish \n'),
        },
        open_vending = '[E] - Open Vending',
    }
}
