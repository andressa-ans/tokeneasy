module.exports = function (api) {
  api.cache(true);
  return {
    presets: ["babel-preset-expo"],
    plugins: [
      [
        "module-resolver",
        {
          root: ["./src"],
          alias: {
            "@assets": "./src/assets",
            "@theme": "./src/theme",
            "@screens": "./src/screens",
            "@routes": "./src/routes",
            "@components": "./src/components",
            "@utils": "./src/utils",
          },
        },
      ],
    ],
  };
};
