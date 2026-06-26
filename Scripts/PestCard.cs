using Godot;
using System;
using System.Collections.Generic;

namespace StackFarming
{
    public partial class PestCard : BaseCard
    {
        [Export] public float DamagePerSecond { get; set; } = 5f;
        [Export] public float TargetSearchInterval { get; set; } = 1.0f;

        private BaseCard _targetCrop = null;
        private float _timer = 0f;

        public override void _Ready()
        {
            base._Ready();
            Role = CardRole.Creature;
            Type = CardType.Pest;
            CardName = "害虫";
            
            // 害虫健康值
            if (Health <= 0f) Health = 50f;
        }

        public override void _Process(double delta)
        {
            // 如果正在拖拽，调用 base._Process 处理位置更新，并临时清除附着目标
            if (_isDragging)
            {
                base._Process(delta);
                _targetCrop = null;
                return;
            }

            base._Process(delta); // 运行基类 Process（用于刷新 UI 渲染等）

            if (Health <= 0f) return; 

            _timer += (float)delta;
            if (_timer >= TargetSearchInterval)
            {
                _timer = 0f;
                ExecutePestBehavior(TargetSearchInterval);
            }

            // 视觉效果：平滑移动到附着的作物位置
            if (_targetCrop != null && GodotObject.IsInstanceValid(_targetCrop))
            {
                GlobalPosition = GlobalPosition.Lerp(_targetCrop.GlobalPosition + new Vector2(10, -10), (float)delta * 5f);
            }
        }

        /// <summary>
        /// 害虫卡不参与堆叠计算。重写 StackOn 确保无法被拖拽放置在其他卡牌上或作为堆叠容器。
        /// </summary>
        public override void StackOn(BaseCard newParent)
        {
            // 害虫无法参与正常堆叠，静默忽略堆叠请求
            Unstack();
        }

        private void ExecutePestBehavior(float seconds)
        {
            // 检查目标作物是否失效
            if (_targetCrop == null || !GodotObject.IsInstanceValid(_targetCrop) || _targetCrop.Health <= 0f)
            {
                _targetCrop = null;
                FindNewTargetCrop();
            }

            // 附着攻击逻辑：每秒扣减目标作物的 Health (ValueA)
            if (_targetCrop != null && GodotObject.IsInstanceValid(_targetCrop))
            {
                GD.Print($"[Pest Attack] Pest {CardName} is attacking crop {_targetCrop.CardName}. Damaging health by {DamagePerSecond * seconds}.");
                _targetCrop.Health -= DamagePerSecond * seconds;
            }
        }

        private void FindNewTargetCrop()
        {
            // 寻找当前所在的容器
            ContainerCard container = FindCurrentContainer();
            if (container == null) return;

            // 获取该地块上的所有作物
            List<BaseCard> stack = container.GetStackChain();
            List<BaseCard> crops = new List<BaseCard>();
            
            foreach (var card in stack)
            {
                if (card.Type == CardType.Crop && card.Health > 0f)
                {
                    crops.Add(card);
                }
            }

            if (crops.Count > 0)
            {
                // 随机选择一个作物附着
                int randomIndex = GD.RandRange(0, crops.Count - 1);
                _targetCrop = crops[randomIndex];
                GD.Print($"[Pest] Attached to new crop target: {_targetCrop.CardName}");
            }
        }

        private ContainerCard FindCurrentContainer()
        {
            // 物理检测重叠的容器卡
            foreach (Area2D area in GetOverlappingAreas())
            {
                if (area is ContainerCard container && GodotObject.IsInstanceValid(container))
                {
                    return container;
                }
            }
            return null;
        }
    }
}
