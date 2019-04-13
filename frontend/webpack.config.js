const path = require('path');
const ExtractTextPlugin = require('extract-text-webpack-plugin');

module.exports = {
  entry: './javascripts/application.js',
  output: {
    path: path.resolve(__dirname, '../public/assets'),
    filename: 'javascripts/application.js'
  },
  module: {
    rules: [{
      test: /\.scss$/,
      use: ExtractTextPlugin.extract({
        fallback: 'style-loader',
        use: [
          { loader: 'css-loader' },
          { loader: 'sass-loader' },
          {
            loader: 'postcss-loader',
            options: {
              sourceMap: true,
              plugins: [
                require('cssnano')({ preset: 'default' })
              ]
            },
          }
        ]
      })
    }]
  },
  plugins: [
    new ExtractTextPlugin('stylesheets/application.css')
  ]
};
