fx_version 'cerulean'
game 'gta5'

author 'kariee'
version '1.0.0'
description 'Compact vehicle control menu'

ui_page 'web/dist/index.html'

shared_script '@es_extended/imports.lua'

files {
    'web/dist/index.html',
    'web/dist/assets/*'
}

client_script 'client/client.lua'
