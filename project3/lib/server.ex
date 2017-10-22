# defmodule WORKER do
#
#
# end
#
#
#
# class Master(numNodes: Int, numRequests: Int) extends Actor {
#
#   var log4 = ceil(log(numNodes.toDouble) / log(4)).toInt
#   var nodeIDSpace: Int = pow(4, log4).toInt
#   var ranlist = new ArrayBuffer[Int]()
#   var firstGroup = new ArrayBuffer[Int]()
#   var numFirstGroup: Int = if (numNodes <= 1024) numNodes else 1024 //Default first group size, can be changed later
#   var i: Int = -1
#   var numJoined: Int = 0
#   var numNotInBoth: Int = 0
#   var numRouted: Int = 0
#   var numHops: Int = 0
#   var numRouteNotInBoth: Int = 0
#
#   println("Number Of Nodes: " + numNodes)
#   println("Node ID Space: 0 ~ " + (nodeIDSpace - 1))
#   println("Number Of Request Per Node: " + numRequests)
#
#   for (i <- 0 until nodeIDSpace) { //Node space form 0 to node id space
#     ranlist += i
#   }
#   ranlist = Random.shuffle(ranlist) //Random list index from 0 to nodes-2 there is no node 0!
#
#   for (i <- 0 until numFirstGroup) {
#     firstGroup += ranlist(i)
#   }
#   //println(firstGroup)
#
#   for (i <- 0 until numNodes) {
#     context.actorOf(Props(new PastryActor(numNodes, numRequests, ranlist(i), log4)), name = String.valueOf(ranlist(i))) //Create nodes
#   }
#
#
#
# }
