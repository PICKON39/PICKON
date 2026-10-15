PICKON/
├── .claude-plugin/
│   └── marketplace.json
└── plugins/
    └── 플러그인이름/
        ├── .claude-plugin/
        │   └── plugin.json
        └── skills/ ...
{
  "name": "pickon",
  "owner": { "name": "PICKON39" },
  "plugins": [
    {
      "name": "플러그인이름",
      "source": "./plugins/플러그인이름",
      "description": "플러그인 설명"
    }
  ]
}
