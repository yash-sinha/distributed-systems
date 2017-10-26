• Team members
Geetanjli Chugh (21885647) | Yash Sinha (15618171)

• How to run
1. Unzip project3.tgz
2. Run ./project3 numNodes numRequests 
   Eg. ./project3 100 2
   We have used default numNodes as 64 and default numRequests as 1

• What is working
The main assignment of node joins and routing is working for the Pastry protocol.
We are getting average number of hops as less than or equal to logN/log4 as expected.

We have assumed the number of hops as the number of intermediary nodes between source and destination.(https://en.wikipedia.org/wiki/Hop_(networking))  
If node1 has to send the request to node100 and we have intermediary nodes as node5 and node50, the number of hops is 2. If node1 has to send to node3 and node3 is already there in the leaflet, so node1 can directly send the request to node3 and thus hops = 0.

• What is the largest network you managed to deal with
We tested for a maximum of 10000 nodes. The average number of hops we got was 3.72. 
Larger networks may be supported but will take large amount of time.