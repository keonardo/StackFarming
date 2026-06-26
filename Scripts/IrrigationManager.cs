using Godot;
using System;
using System.Collections.Generic;

namespace StackFarming
{
    public partial class IrrigationManager : Node
    {
        public static IrrigationManager Instance { get; private set; }

        [Export] public float ConnectionDistance { get; set; } = 160f; // 连接判定物理距离 (像素)
        [Export] public float DriftDistance { get; set; } = 250f;      // 漂移的最大邻近距离 (像素)
        [Export] public float DriftInterval { get; set; } = 5.0f;       // 物质漂移检查周期 (秒)
        [Export] public float LinkageCheckInterval { get; set; } = 1.0f;// 水利链路判定周期 (秒)

        private float _driftTimer = 0f;
        private float _linkageTimer = 0f;

        public override void _EnterTree()
        {
            Instance = this;
        }

        public override void _ExitTree()
        {
            if (Instance == this)
            {
                Instance = null;
            }
        }

        public override void _Process(double delta)
        {
            _linkageTimer += (float)delta;
            if (_linkageTimer >= LinkageCheckInterval)
            {
                _linkageTimer = 0f;
                CheckIrrigationLinkage();
            }

            _driftTimer += (float)delta;
            if (_driftTimer >= DriftInterval)
            {
                _driftTimer = 0f;
                ProcessSubstanceDrift();
            }
        }

        /// <summary>
        /// 链路连接判定：检测河道、水渠和农田卡牌在Godot场景中的物理位置
        /// 若水渠成功连接水源与农田，将农田的IsIrrigated设为true
        /// </summary>
        public void CheckIrrigationLinkage()
        {
            List<BaseCard> rivers = new List<BaseCard>();
            List<BaseCard> canals = new List<BaseCard>();
            List<ContainerCard> containers = new List<ContainerCard>();

            FindCardsInTree(GetTree().Root, rivers, canals, containers);

            // 广度优先搜索 (BFS) 初始化：从所有水源 (河道) 开始搜索
            Queue<BaseCard> queue = new Queue<BaseCard>();
            HashSet<BaseCard> visited = new HashSet<BaseCard>();

            foreach (var river in rivers)
            {
                queue.Enqueue(river);
                visited.Add(river);
            }

            HashSet<ContainerCard> irrigatedContainers = new HashSet<ContainerCard>();

            // BFS 执行
            while (queue.Count > 0)
            {
                BaseCard current = queue.Dequeue();

                if (current is ContainerCard cCard)
                {
                    irrigatedContainers.Add(cCard);
                }

                // 检查邻近的水渠
                foreach (var canal in canals)
                {
                    if (!visited.Contains(canal) && current.GlobalPosition.DistanceTo(canal.GlobalPosition) <= ConnectionDistance)
                    {
                        visited.Add(canal);
                        queue.Enqueue(canal);
                    }
                }

                // 检查邻近的农田/容器
                foreach (var container in containers)
                {
                    if (!visited.Contains(container) && current.GlobalPosition.DistanceTo(container.GlobalPosition) <= ConnectionDistance)
                    {
                        visited.Add(container);
                        queue.Enqueue(container);
                    }
                }
            }

            // 更新容器卡的灌溉状态
            foreach (var container in containers)
            {
                // 大旱事件发生时芒种会屏蔽非深水鱼凼地块的灌溉，在SolarTermEngine中会有配合
                bool isIrrigatedByCanal = irrigatedContainers.Contains(container);

                if (SolarTermEngine.CurrentTerm == SolarTerm.Mangzhong)
                {
                    // 芒种大旱：关闭所有非 [深水鱼凼] 地块的滋润属性
                    if (container.Type != CardType.DeepWaterFishPond)
                    {
                        container.IsIrrigated = false;
                        continue;
                    }
                }

                container.IsIrrigated = isIrrigatedByCanal;
            }
        }

        /// <summary>
        /// 物质流动：每隔固定时间，上游容器中多余的粪便卡向邻近的下游容器“漂移”。
        /// 上游与下游的判定：Y轴坐标较小者为上游，较大者为下游（水往低处流）。
        /// </summary>
        private void ProcessSubstanceDrift()
        {
            List<BaseCard> rivers = new List<BaseCard>();
            List<BaseCard> canals = new List<BaseCard>();
            List<ContainerCard> containers = new List<ContainerCard>();

            FindCardsInTree(GetTree().Root, rivers, canals, containers);

            foreach (var upstream in containers)
            {
                List<BaseCard> stack = upstream.GetStackChain();
                List<BaseCard> fecesCards = new List<BaseCard>();
                
                foreach (var card in stack)
                {
                    if (card.Type == CardType.Feces && GodotObject.IsInstanceValid(card))
                    {
                        fecesCards.Add(card);
                    }
                }

                // 拥有多张粪便卡时（堆叠数量大于1），将顶部的多余粪便卡漂移至邻近的下游
                if (fecesCards.Count > 1)
                {
                    ContainerCard downstreamTarget = null;
                    float maxYDiff = 0f;

                    foreach (var potentialDownstream in containers)
                    {
                        if (potentialDownstream == upstream) continue;

                        float dist = upstream.GlobalPosition.DistanceTo(potentialDownstream.GlobalPosition);
                        if (dist <= DriftDistance)
                        {
                            float yDiff = potentialDownstream.GlobalPosition.Y - upstream.GlobalPosition.Y;
                            // 下游的Y轴必须大于上游（设定向下倾斜，Y值更大）
                            if (yDiff > 25f && yDiff > maxYDiff)
                            {
                                maxYDiff = yDiff;
                                downstreamTarget = potentialDownstream;
                            }
                        }
                    }

                    if (downstreamTarget != null)
                    {
                        BaseCard extraFeces = fecesCards[fecesCards.Count - 1];
                        GD.Print($"[Irrigation Fecal Drift] Feces card {extraFeces.CardName} drifted from {upstream.CardName} downstream to {downstreamTarget.CardName}");

                        // 解除原堆叠
                        extraFeces.Unstack();

                        // 放置在下游地块位置并堆叠其上
                        extraFeces.GlobalPosition = downstreamTarget.GlobalPosition + new Vector2((float)GD.RandRange(-10, 10), (float)GD.RandRange(-10, 10));
                        extraFeces.StackOn(downstreamTarget);
                    }
                }
            }
        }

        private void FindCardsInTree(Node node, List<BaseCard> rivers, List<BaseCard> canals, List<ContainerCard> containers)
        {
            if (node is BaseCard card && GodotObject.IsInstanceValid(card))
            {
                if (card.Type == CardType.River) rivers.Add(card);
                else if (card.Type == CardType.Canal) canals.Add(card);
                else if (card is ContainerCard container) containers.Add(container);
            }

            for (int i = 0; i < node.GetChildCount(); i++)
            {
                FindCardsInTree(node.GetChild(i), rivers, canals, containers);
            }
        }
    }
}
