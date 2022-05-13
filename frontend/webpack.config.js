const path = require('path');
const MiniCssExtractPlugin = require('mini-css-extract-plugin');

module.exports = {
  entry: './javascripts/entrypoint.js',
  output: {
    path: path.resolve(__dirname, '../public/assets'),
    filename: 'javascripts/application.js'
  },
  module: {
    rules: [{
      test: /\.scss$/,
      use: [
        MiniCssExtractPlugin.loader,
        'css-loader',
        'sass-loader',
      ]
    }]
  },
  plugins: [
    new MiniCssExtractPlugin({
      filename: 'stylesheets/application.css'
    })
  ]
};
