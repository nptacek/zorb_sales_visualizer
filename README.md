# zorb_sales_visualizer
a recent zorb sales visualizer built with ZORA API and canvasJS

In this tutorial you'll learn how to build a simple NFT sales dashboard using Zora's powerful new API.<img width="1012" alt="Screen Shot 2022-06-24 at 1 05 14 AM" src="https://user-images.githubusercontent.com/120711/175480069-697705f3-f1bb-4f06-a1f5-bf3486ea54d1.png">

"Can I use the new @ourZORA API to visualize recent Zorb sales by color?" 🤔

Let's start by figuring out what data we'll need if we want to display recent Zorbs sales on scatter chart.

At a bare minimum, we'll need two pieces of data in order to plot a point: the timestamp for the sale, and the sale price.

Here’s the GraphQL query that will fetch that data from the Zora API:

<img width="669" alt="Screen Shot 2022-06-23 at 4 05 24 PM" src="https://user-images.githubusercontent.com/120711/175488009-e6407d1f-ae74-4f99-8d36-123739cb4bc8.png">

Now, in practice we’re going to want to request more information from Zora’s API than just that.

Keep in mind that the goal is not only to display recent Zorb sales, but to do so in a way that indicates the color of each Zorb.

Don’t worry about how we’ll display the data just yet. For now, we’re just in the planning stage. What other data might we want?

I can immediately think of two pieces of data:

• Token ID

• Token Metadata

The token ID will come in handy during testing and troubleshooting — if we’re in any doubt as to the accuracy of the data, we can always use the token ID to cross-reference the transaction data on etherscan.io.

The token metadata is where we’ll find information on the Zorb’s display image, which changes based upon wallet address.

Further, we can set some constraints on our GraphQL query — by limiting it to the most recent 500 sales, we can create a one-shot query, and won’t need to worry about handling multiple pages of results.

This is not only kinder on Zora’s API servers, it keeps things simpler on the code end of things as well.

Remember, we can always expand our program’s capabilities in the future!

So, what does our final ZORA API query look like?

<img width="664" alt="Screen Shot 2022-06-23 at 4 41 26 PM" src="https://user-images.githubusercontent.com/120711/175488791-b345e86a-2a96-466a-b559-946a3b393f33.png">

We can verify the output for our query on Zora’s API Playground and get an idea of the format of the data we’ll be working with:

<img width="568" alt="Screen Shot 2022-06-23 at 4 41 07 PM" src="https://user-images.githubusercontent.com/120711/175489323-cf452029-2ac1-4913-ba82-8298d5fe2e79.png">

It looks like all the information we requested is there, but what about that big blob of data for the Zorb’s image?

How are we supposed to get from that to a specific Zorb color to display?

We know from the data URI scheme that the image data is base64-encoded, so let’s decode it to see what it looks like.

You can do this in code, but there are some websites where you can test it out as well.

Just don’t forget to strip out the data:image/svg+xml;base64, prefix if you’re going with the website route, or it won’t decode correctly.

Here’s what the base64-decoded image data looks like:

<img width="540" alt="Screen Shot 2022-06-23 at 5 26 17 PM" src="https://user-images.githubusercontent.com/120711/175489822-e3d832f5-c43d-41b6-862c-26425b2676c4.png">

If you copy and paste the output into a plain-text .html file and then open it with your web browser, you should see the Zorb in all its glory:

<img width="912" alt="Screen Shot 2022-06-23 at 5 31 30 PM" src="https://user-images.githubusercontent.com/120711/175490317-a8f89e4d-1847-4226-9f53-6db5b1e46f58.png">

So, we’re getting closer, at least we can see how the image is constructed for any given Zorb.

There is actually a ton of interesting code to dig into if you’re interested in the technical implementation of the Zorb color-changing side of things.

Take a look at the gradientForAddress function in the Zorbs smart contract if so.

For the purposes of this tutorial, however, we’re keeping things simple, and we can analyze the SVG output without actually needing to understand the implementation details.

The only thing we care about is identifying the main display color for each Zorb.

Looking at the SVG output, we can see five references to something called stop-color, each with an hsl value.

HSL stands for Hue, Saturation, Luminosity, and is a way of representing specific colors. Bingo.

We can verify that the HSL values we see in the decoded svg image data match the colors of our Zorb on a site like HSLPicker.

<img width="650" alt="Screen Shot 2022-06-23 at 5 59 51 PM" src="https://user-images.githubusercontent.com/120711/175490606-5eca69e6-dede-4f4b-be43-d64cd0cdfd67.png">

There are a couple things to note here: some Zorbs are more than one color, others aren’t.

It’s all based on the wallet address holding the Zorb.

It’s up to you how you want to visually convey the Zorb’s color–for example, you might want to calculate the median of all five HSL values, and use that for the display color.

For the purposes of this tutorial, however, we’re simply going to stick with the value that corresponds to the lower left of each Zorb image (i.e. the last stop-color value).

Before we continue, let’s take a look at where we’re at:

1. We know how to ask the Zora API for recent Zorbs sales data.

2. We know how to decode the SVG image data for any Zorb.

3. We know how determine the HSL values that correspond to a Zorb’s color.

So we’ve got all the data we need to plot any given Zorb sale in the correct color, where do we go from here? How do we actually display this data in a meaningful way?

<b>Displaying the Data</b>

If you’re not opposed to working with third-party libraries, canvasJS offers a number of highly customizable options, and will work perfectly for the purposes of this tutorial.

I ended up going for the Multi Series Scatter/Point Chart, as it allows marker customization on a per-entry basis, perfect for the multitude of Zorb colors we’ll need to handle.

Even better, it can handle HSL values right out of the box, so you don’t have to worry about converting the color to RGB or hex.

<img width="540" alt="Screen Shot 2022-06-23 at 11 54 53 PM" src="https://user-images.githubusercontent.com/120711/175491791-e86ca29d-1576-4933-9588-71ab9b4bac1a.png">

Looking at the documentation, it appears we’ve got a couple options when it comes to handling the timestamps for Zorb sales.

We can either construct a new JavaScript Date object, or we can specify a timestamp in milliseconds.

Date conversions are notoriously tricky things, especially when you start accounting for time zones and locales, but we don’t need to go that far in this tutorial.

Converting a timestamp from the format we get from Zora’s API to one we can use with canvasJS is as simple as getting the Unix timestamp and multiplying it by 1000 to get a timestamp in milliseconds.

Passing that along to canvasJS is all we need to do, canvasJS handles the rest.

You’ll definitely want to dig around in the canvasJS documentation, there are tons of customization options that I’m only scratching the surface of here.

Here’s one way of setting it up:

<img width="734" alt="Screen Shot 2022-06-23 at 11 53 10 PM" src="https://user-images.githubusercontent.com/120711/175492085-a4c70b68-a356-4e69-a8f2-776f79f485da.png">

I added a few basic design touches, such as setting the chart background color to black, and giving each Zorb sales entry a white outline to make it stand out a bit.

When you mouse over a data point, a tooltip will show the sale date, price, and token ID.

Some test data allows us to get an idea of what it’ll look like once we start charting data points:

<img width="889" alt="Screen Shot 2022-06-24 at 12 01 45 AM" src="https://user-images.githubusercontent.com/120711/175492269-bfd34221-8ba6-4554-bc58-f8c4764416b9.png">

So, now that we know what data we need to get from Zora’s API, how it’s formatted, and the format we need it to be in for canvasJS, we’re tasked with the matter of actually getting the data from the Zora API, parsing it, and sending it to canvasJS.

<b>Bringing it all together</b>

I’ve implemented this part in Objective-C, but you can use whatever programming language you’re most comfortable with — plenty of libraries and frameworks exist allowing you to call GraphQL directly from JavaScript.

In this case we’ll be using an extended version of Ponder–my entry for the Zora API Hackathon–to power the interactions with Zora’s API server.

First, we’ll request the data we want from Zora’s API server using a GraphQL query.

Once we get a response back from the server, we’ll parse the data a bit in order to get it into the correct format to use with canvasJS.

This mostly involves base64 decoding and slicing up the resulting strings to grab the HSL value for each Zorb sale, and keeping track of it along with some other basic sales data, then passing it along to another function for further parsing.

<img width="1072" alt="Screen Shot 2022-06-24 at 12 39 20 AM" src="https://user-images.githubusercontent.com/120711/175492665-371b5baf-d619-425a-bfdc-99ca801f6016.png">

Next, we create our canvasJS template directly in code, setting the dataPoints to our previously created array of reformatted sales data.

We’re also including a custom handler for click events on individual Zorb sale markers.

This allows us to send the tokenId back to objective-c, where we can use it to open a webpage directly to that particular Zorb.

This makes verification of sales data and Zorb color a snap.

<img width="1072" alt="Screen Shot 2022-06-24 at 12 57 31 AM" src="https://user-images.githubusercontent.com/120711/175492961-6a17caca-8d27-41d6-bdbf-9542c4ea164b.png">

When we put it all together, here’s the final result:

<img width="1012" alt="Screen Shot 2022-06-24 at 1 04 11 AM" src="https://user-images.githubusercontent.com/120711/175493047-21e71a2f-a618-41f4-82d6-07b450a27f4d.png">

<b>Note: You may find Zorb display colors don’t match up with what you see on OpenSea or other sites. Try refreshing the metadata and you should see the correct colors. You might notice price discrepancies across various marketplaces, always verify data on-chain when possible.</b>

So, there you have it.

Using the new Zora API, it’s definitely possible to keep track of recent Zorb sales by color.

This tutorial only scratches the surface of what’s possible when you combine Zora API with canvasJS.

You can find the tutorial code over on github if you want to play around with it yourself.

I’d love to see your creations, please let me know what you come up with!

<b>References</b>

Tutorial writeup on Medium: https://nptacek.medium.com/building-with-zora-api-a6d06e2eb6ff

zorb_sales_visualizer source code: https://github.com/nptacek/zorb_sales_visualizer

Zora API Reference: https://docs.zora.co/docs/zora-api/intro

Zora API Playground: https://playground.api.zora.co

canvasJS Documentation: https://canvasjs.com/docs/charts/basics-of-creating-html5-chart/

canvasJS scatter point chart demo: https://canvasjs.com/javascript-charts/multi-series-scatter-point-chart/
