#!/bin/bash
echo "=== EKS Dev Cluster Cost Report ==="
echo ""

# Get current date
DATE=$(date +"%Y-%m-%d")

echo "Date: $DATE"
echo ""

echo "Cost Breakdown (Estimated):"
echo "----------------------------"
echo "1. EKS Control Plane:      $73.00/month"
echo "2. EC2 Worker Nodes:       $15-30/month"
echo "   - Type: t3.small spot"
echo "   - Count: 1-2"
echo "   - Hours: ${var.enable_scheduled_scaling ? '12h/day' : '24h/day'}"
echo "3. EBS Storage (20GB):     $2/month"
echo "4. NAT Gateway:           $32.00/month"
echo "5. ECR Storage:           < $1/month"
echo "6. Data Transfer:         < $5/month"
echo ""
echo "Total (without optimizations): $122-135/month"
echo ""
echo "Active Optimizations:"
echo "---------------------"
echo "✅ Spot Instances:          ~70% savings"
if [ "$ENABLE_SCHEDULED_SCALING" = "true" ]; then
    echo "✅ Scheduled Scaling:       ~50% savings"
    echo "   Active: ${var.off_hours_end} to ${var.off_hours_start}"
fi
if [ "$SCALE_TO_ZERO_WEEKENDS" = "true" ]; then
    echo "✅ Weekend Shutdown:        ~30% savings"
fi
if [ "$ENABLE_KARPENTER" = "true" ]; then
    echo "✅ Karpenter:              ~20% savings"
fi
echo ""
echo "Optimized Total:           $20-50/month"
echo ""
echo "Tips for further savings:"
echo "-------------------------"
echo "1. Run './scripts/destroy.sh' when not using cluster"
echo "2. Consider using local k3d/kind for development"
echo "3. Monitor costs in AWS Cost Explorer"
echo "4. Set up billing alerts"
echo ""