const path = require('path');
const VueLoaderPlugin = require('vue-loader/lib/plugin');
const ExtractTextPlugin = require("extract-text-webpack-plugin");
const webpack = require('webpack');

module.exports = {
  entry: './javascripts/entrypoint.js',
  output: {
    path: path.resolve(__dirname, '../public/assets'),
    publicPath: '/',
    filename: 'assets/javascripts/application.js'
  },
  module: {
    rules: [
      {
        test: /\.vue$/,
        loader: 'vue-loader'
      },
      {
        test: /\.js$/,
        loader: 'babel-loader'
      },
      {
        test: /\.scss$/,
        use: ExtractTextPlugin.extract({
          fallback: 'style-loader',
          use: [
            'css-loader',
            {
              loader: 'postcss-loader',
              options: {
                sourceMap: true,
                plugins: [
                  require('cssnano')({ preset: 'default' })
                ]
              },
            },
            'sass-loader'
          ]
        })
      },
      {
        test: /\.css$/,
        use: [
          'vue-style-loader',
          'css-loader'
        ]
      }
    ]
  },
  devServer: {
    contentBase: path.join(__dirname, '../public'),
    host: '0.0.0.0',
    port: 8080,
    hot: true
  },
  plugins: [
    new VueLoaderPlugin(),
    new ExtractTextPlugin('stylesheets/application.css'),
    new webpack.HotModuleReplacementPlugin()
  ]
};
