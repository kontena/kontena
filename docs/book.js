module.exports = {
  title: "Kontena",
  plugins: ["edit-link", "prism", "-highlight", "github", "anchorjs", "collapsible-menu"],
  pluginsConfig: {
    "edit-link": {
      base: "https://github.com/kontena/kontena/tree/master/docs",
      label: "Edit This Page"
    },
    github: {
      url: "https://github.com/kontena/kontena/"
    }
  },
  variables: {
    ga: process.env.GA_CODE || '',
    hubspot: process.env.HUBSPOT_CODE || ''
  }
};
