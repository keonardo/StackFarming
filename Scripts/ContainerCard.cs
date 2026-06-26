using Godot;
using System;
using System.Collections.Generic;

namespace StackFarming
{
    public partial class ContainerCard : BaseCard
    {
        [Export] public bool IsIrrigated { get; set; } = false;
        [Export] public float DryHealthDecayPerSecond { get; set; } = 15f; // 无水滋润时健康衰减速度
        [Export] public int FecesPondTurningThreshold { get; set; } = 3;  // 触发翻塘的粪便数量阈值

        [Signal]
        public delegate void PondTurnedEventHandler(ContainerCard container);

        private float _survivalTimer = 0f;

        public override void _Ready()
        {
            base._Ready();
            Role = CardRole.Container;
            
            if (Capacity <= 0f) Capacity = 5f; // 默认承载力
            if (Moisture <= 0f) Moisture = 100f; // 默认滋润度
        }

        public override void _Process(double delta)
        {
            base._Process(delta);

            _survivalTimer += (float)delta;
            if (_survivalTimer >= 1.0f)
            {
                _survivalTimer = 0f;
                CheckSurvivalAndImbalance(1.0f);
            }
        }

        /// <summary>
        /// 检查生存环境和环境失衡状态
        /// </summary>
        private void CheckSurvivalAndImbalance(float seconds)
        {
            List<BaseCard> stack = GetStackChain();
            
            int fecesCount = 0;
            int cropCount = 0;
            List<BaseCard> aquaticCreatures = new List<BaseCard>();
            List<BaseCard> fishCreatures = new List<BaseCard>();

            foreach (var card in stack)
            {
                if (card == this) continue; // 排除容器自身

                if (card.Type == CardType.Feces)
                {
                    fecesCount++;
                }
                else if (card.Type == CardType.Crop)
                {
                    cropCount++;
                    // 水稻作为水生作物
                    if (card.CardName.Contains("水稻") || card.CardName.ToLower().Contains("rice"))
                    {
                        aquaticCreatures.Add(card);
                    }
                }
                else if (card.Type == CardType.Fish)
                {
                    aquaticCreatures.Add(card);
                    fishCreatures.Add(card);
                }
            }

            // 1. 滋润状态压制：若容器 IsIrrigated == false，则其上所有水生生物（水稻、鱼）持续失血
            if (!IsIrrigated)
            {
                foreach (var creature in aquaticCreatures)
                {
                    if (GodotObject.IsInstanceValid(creature) && creature.Health > 0f)
                    {
                        GD.Print($"[Moisture Pressure] {creature.CardName} on {CardName} is drying out! Health -{DryHealthDecayPerSecond * seconds}");
                        creature.Health -= DryHealthDecayPerSecond * seconds;
                    }
                }
            }

            // 2. 失衡危机：若地块上 [粪便卡] 数量过多且无作物吸收，触发‘翻塘’状态，瞬间清空所有鱼类健康值
            if (fecesCount >= FecesPondTurningThreshold && cropCount == 0)
            {
                if (fishCreatures.Count > 0)
                {
                    GD.PrintErr($"[POND TURNING] {CardName} flipped pond! Too much feces ({fecesCount}) and no crops. Fish are dying!");
                    EmitSignal(SignalName.PondTurned, this);
                    
                    foreach (var fish in fishCreatures)
                    {
                        if (GodotObject.IsInstanceValid(fish) && fish.Health > 0f)
                        {
                            fish.Health = 0f; // 瞬间清空健康值，触发 OnHealthZero()
                        }
                    }
                }
            }
        }

        /// <summary>
        /// 获取当前地块上的动物数量
        /// </summary>
        public int GetAnimalCount()
        {
            List<BaseCard> stack = GetStackChain();
            int count = 0;
            foreach (var card in stack)
            {
                if (card.Type == CardType.Animal)
                {
                    count++;
                }
            }
            return count;
        }

        /// <summary>
        /// 施加动物背叛伤害：扣减地块上作物卡牌的健康值
        /// </summary>
        public void ApplyAnimalBetrayalDamage(float damage)
        {
            List<BaseCard> stack = GetStackChain();
            foreach (var card in stack)
            {
                if (card.Type == CardType.Crop && GodotObject.IsInstanceValid(card) && card.Health > 0f)
                {
                    GD.Print($"[Betrayal Damage] Crop {card.CardName} damaged by animals. Health -{damage}");
                    card.Health -= damage;
                }
            }
        }
    }
}
