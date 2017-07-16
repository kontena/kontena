module.exports = {
  title: "Kontena",
  plugins: [
    "edit-link", "prism", "-highlight", "github", "anchorjs", "collapsible-menu", "ga", "scripts"
  ],
  pluginsConfig: {
    "edit-link": {
      base: "https://github.com/kontena/kontena/tree/master/docs",
      label: "Edit This Page"
    },
    github: {
      url: "https://github.com/kontena/kontena/"
    },
    ga: {
      token: process.env.GA_CODE || ""
    },
    scripts: {
      files: [
        "./_scripts/hs.js"
      ]
    },
    hs: {
      code: process.env.HUBSPOT_CODE || ""
    }
  },
  variables: {
  }
};
