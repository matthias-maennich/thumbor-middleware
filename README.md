# About

This is a extract of a POC to provide an API for smart image cropping and resizing. The idea was to integrate a middleware service into a rails application which proxies image requests to a [thumbor](https://github.com/thumbor/thumbor) service that accepts only whitelisted formats and options. After running into multiple problems this idea was abandoned. A middleware for this is an especially bad idea if requested images are also coming from the same rails application - this quickly results in a deadlock.  
So this project is more of a post mortem/ reference for my personal use.


# Setup

Before you can use the service you need to install thumbor. Check out [http://thumbor.org/](http://thumbor.org/) for installation and configuration instructions.

To setup the proxy within your application you just have add the service to your middleware stack within your `application.rb`.


```ruby
# config/application.rb

allowed_formats = {
  'formats' => {'size_64x64'   => '64x64',
                'size_128x128' => '128x128',
                'size_256x256' => '256x256',
                'size_768x384' => '768x384',
                'size_384x192' => '384x192'}
}

config.middleware.insert_after(Rack::Runtime,
                               Thumbor::Middleware,
                               service_namespace: %r{^\/thumbor},
                               base_url: ENV['THUMBOR_BASE_URL'],
                               formats: allowed_formats)
```


Make sure to set the correct thumbor base url in your before starting the rails server.
Default base url: `THUMBOR_BASE_URL=localhost:8888/unsafe`


# Usage

The service can be called via `<HOST>/thumbor?url=<IMAGE_URL>&<PARAMS>`  
There are 2 actions available: `clip` and `resize`.  

----------------------

### Action: `resize`

__Example URL__: `localhost:3000/thumbor?url=example.com/example.jpg&action=resize&format=128x128`  
With the action set to resize, the image will be auto-resized (shrinked) to fit in an imaginary box of the dimensions of the given format.  
[Details about fit-in function](http://thumbor.readthedocs.io/en/latest/usage.html#fit-in)

----------------------

### Action: `clip`

__Example URL__: `localhost:3000/thumbor?url=example.com/example.jpg&action=clip&format=size_768x384`  
Resizes and crops the image to fit in the given format. This one should be used if you are sure about the exact format you want to have. By default smart-cropping will be applied to the image. smart-cropping means that it tries to find important focal points in the picture (e.g. facial detection) and crops with the focal point as the center. To disable smart-cropping add the parameter: `smart=false`  
[Details about detection algorithms](http://thumbor.readthedocs.io/en/latest/detection_algorithms.html)
