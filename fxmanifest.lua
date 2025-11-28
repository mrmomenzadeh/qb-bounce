fx_version 'cerulean'
game 'gta5'
lua54 'yes'

description 'Vehicle Bounce Mode for QBCore'
author 'galaxy community'
version '1.0.0'

shared_script 'config.lua'
client_script 'client.lua'
server_script 'server.lua'

dependencies {
    'qb-core',
    'oxmysql'
}
