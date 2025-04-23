--[[ FX Information ]] --
fx_version 'cerulean'
use_experimental_fxv2_oal 'yes'
lua54 'yes'
game 'gta5'
author 'uniq-team'
repository 'https://github.com/uniqscripts/uniq_vendingmachine'
version '1.3.1'


dependencies {
    '/server:6116',
    '/onesync',
    'oxmysql',
    'ox_lib',
	'ox_inventory'
}

shared_scripts {
	'@ox_lib/init.lua',
	'config/config.lua',
	'locales.lua',
	'locales/*.lua',
	'bridge/framework.lua',
}
server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'bridge/**/server.lua',
	'server/*'
}
client_scripts {
	'bridge/**/client.lua',
	'client/*'
}