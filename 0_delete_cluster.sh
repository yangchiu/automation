multipass delete c1-control &
echo "delete c1-control"
multipass delete c1-worker1 &
echo "delete c1-worker1"
multipass delete c1-worker2 &
echo "delete c1-worker2"
multipass delete c1-worker3 &
echo "delete c1-worker3"
multipass purge &
echo "purge finished!"
